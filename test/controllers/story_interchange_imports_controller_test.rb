require "test_helper"
require "fileutils"
require "tmpdir"

# The platform-admin page: it previews a folder under the configured root and
# performs the destructive write only for an operator who confirms it. The
# import itself is covered by `StoryInterchangeImportTest`; these cases pin the
# gate, the preview, and the browser-facing refusal.
class StoryInterchangeImportsControllerTest < ActionDispatch::IntegrationTest
  FIXTURE = Rails.root.join("test/fixtures/files/story_interchange/synthetic-universe")

  setup do
    @previous_root = Rails.configuration.x.story_interchange.import_root
    @temporary_directory = Dir.mktmpdir("story-interchange-controller-test")
    @source_root = File.join(@temporary_directory, "sources")
    FileUtils.mkdir_p(@source_root)
    FileUtils.cp_r(FIXTURE, File.join(@source_root, "synthetic-universe"))
    Rails.configuration.x.story_interchange.import_root = @source_root

    @operator = users(:platform_operator)
  end

  teardown do
    Rails.configuration.x.story_interchange.import_root = @previous_root
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
  end

  test "a guest is sent to sign in" do
    get import_url

    assert_redirected_to new_session_url
  end

  test "an account without the platform flag receives 403" do
    sign_in_as users(:user_one)

    get import_url

    assert_response :forbidden
  end

  test "an account without the platform flag cannot write either" do
    sign_in_as users(:user_one)

    post import_url, params: { source: "synthetic-universe", confirm: "1" }

    assert_response :forbidden
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  test "the operator sees the configured folders and no workspace" do
    sign_in_as @operator

    get import_url

    assert_response :success
    assert_select "aside.workspace-sidebar", 0
    assert_select "select[name=source] option", text: "synthetic-universe"
  end

  test "the top bar links to the import page only for an operator" do
    get universes_url
    assert_select "nav .dropdown a[href=?]", import_path, count: 0

    sign_in_as @operator
    get universes_url
    assert_select "nav .dropdown a[href=?]", import_path, text: /Import/
  end

  test "previews the identity, the validator, and the registered slices" do
    sign_in_as @operator

    get import_url(source: "synthetic-universe")

    assert_response :success
    assert_select "h1", text: "Story interchange import"
    assert_includes response.body, "Synthetic Universe"
    assert_includes response.body, "synthetic-universe"
    assert_includes response.body, "Creates a new universe."
    assert_includes response.body, "Canon rules"
    assert_includes response.body, "The source is valid."
    # An open question is reported in the preview rather than silently missing.
    assert_includes response.body, "O-I1"
  end

  test "refuses a source name that is not a folder under the root" do
    sign_in_as @operator

    get import_url(source: "../sources")

    assert_response :success
    assert_includes response.body, "not under the configured import root"
  end

  test "writes nothing without the destructive confirmation" do
    sign_in_as @operator

    post import_url, params: { source: "synthetic-universe" }

    assert_response :unprocessable_content
    assert_includes response.body, "Confirm that the existing records are lost"
    assert_equal 0, Universe.where(slug: "synthetic-universe").count
  end

  test "imports and reports the run after an explicit confirmation" do
    sign_in_as @operator

    post import_url, params: { source: "synthetic-universe", confirm: "1" }

    assert_response :see_other
    assert_redirected_to universe_url("synthetic-universe")

    universe = Universe.find_by!(slug: "synthetic-universe")
    assert_equal @operator, universe.owner
    assert_equal 3, universe.canon_rules.count
    assert_equal 1, universe.characters.count
    assert_equal 1, universe.factions.count

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Imported Synthetic Universe."
    assert_includes response.body, "Canon rules: 3 written"
    assert_includes response.body, "1 reported, not written (O-I1)"
    assert_includes response.body, "Characters: 1 written"
    assert_includes response.body, "Factions: 1 written"
  end

  test "refuses to replace a universe with an open draft" do
    existing = import_source.call.universe
    draft = Draft.create!(user: @operator, universe: existing)
    sign_in_as @operator

    post import_url, params: { source: "synthetic-universe", confirm: "1" }

    assert_response :unprocessable_content
    assert_includes response.body, "Draft #{draft.id}"
    assert_not existing.reload.deleted?
  end

  test "refuses to replace a universe with another member" do
    existing = import_source.call.universe
    member = users(:user_two)
    UniverseMembership.create!(universe: existing, user: member, access_level: "read")
    sign_in_as @operator

    post import_url, params: { source: "synthetic-universe", confirm: "1" }

    assert_response :unprocessable_content
    assert_includes response.body, member.email_address
    assert_not existing.reload.deleted?
  end

  test "an unconfigured root explains itself instead of offering folders" do
    Rails.configuration.x.story_interchange.import_root = nil
    sign_in_as @operator

    get import_url

    assert_response :success
    assert_includes response.body, "No import root configured"
    assert_select "select[name=source]", 0
  end

  private
    def import_source
      StoryInterchange::Import.new(File.join(@source_root, "synthetic-universe"), owner: @operator)
    end
end
