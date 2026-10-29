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

  test "imports, records the run, and reports it on the run's own page" do
    sign_in_as @operator

    post import_url, params: { source: "synthetic-universe", confirm: "1" }

    assert_response :see_other
    run = StoryInterchangeRun.sole
    assert_redirected_to story_interchange_run_url(run)
    # The flash is one sentence: the detail below is the page's job, not a cookie's.
    assert_equal "Imported Synthetic Universe.", flash["notice"]

    universe = Universe.find_by!(slug: "synthetic-universe")
    assert_equal @operator, universe.owner
    assert_equal 3, universe.canon_rules.count
    assert_equal 1, universe.characters.count
    assert_equal 1, universe.factions.count
    assert_equal 1, universe.locations.count
    assert_equal 1, universe.items.count
    assert_equal 1, universe.stories.count
    assert_equal 1, universe.stories.first.plots.count

    assert_equal @operator, run.user
    assert_equal "synthetic-universe", run.source
    assert_equal "Synthetic Universe", run.universe_name
    assert_equal "synthetic-universe", run.universe_slug
    assert_not run.replaced?
    assert_equal 3, run.slices.first.created
    assert_equal [ "O-I1" ], run.slices.first.skipped

    follow_redirect!
    assert_response :success
    assert_includes response.body, "Imported Synthetic Universe."
    assert_includes response.body, "Canon rules"
    assert_includes response.body, "O-I1"
    assert_includes response.body, "ada: Voice"
    assert_select "a[href=?]", universe_path(universe_slug: "synthetic-universe")
  end

  test "a run whose reported list is too large for a session cookie still answers with its page" do
    # The message this page replaced was the full `to_sentence` of every reported id:
    # 300 long ids are more than the 4 KB a session cookie may hold, and the cookie
    # store raised while committing the response — after the write had succeeded.
    sign_in_as @operator
    canon = File.join(@source_root, "synthetic-universe/universe/canon/mechanism.md")
    content = File.read(canon)
    content += "\n" unless content.end_with?("\n")
    content += 300.times.map { |index| "- **O-BLAHBLAHBLAH#{format('%04d', index)}.** Is this answered?" }.join("\n") + "\n"
    File.write(canon, content)

    post import_url, params: { source: "synthetic-universe", confirm: "1" }

    assert_response :see_other
    run = StoryInterchangeRun.sole
    reported = run.slices.flat_map(&:skipped)
    assert_operator reported.join(", ").bytesize, :>, 4096

    follow_redirect!
    assert_response :success
    assert_includes response.body, "O-BLAHBLAHBLAH0299"
  end

  test "a guest is sent to sign in from a run's page" do
    get story_interchange_run_url(create_run)

    assert_redirected_to new_session_url
  end

  test "an account without the platform flag cannot read a run" do
    sign_in_as users(:user_one)

    get story_interchange_run_url(create_run)

    assert_response :forbidden
  end

  test "a run links to its universe only when the reader can open it" do
    private_universe = Universe.create!(
      owner: users(:user_one), name: "Private run universe", slug: "private-run", private: true
    )
    run = create_run(universe_name: private_universe.name, universe_slug: private_universe.slug)
    sign_in_as @operator

    get story_interchange_run_url(run)

    assert_response :success
    assert_includes response.body, private_universe.name
    assert_select "a[href=?]", universe_path(universe_slug: private_universe.slug), count: 0
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
    def create_run(universe_name: "Synthetic Universe", universe_slug: "synthetic-universe")
      StoryInterchangeRun.create!(
        user: @operator,
        source: "synthetic-universe",
        universe_name: universe_name,
        universe_slug: universe_slug,
        outcomes: [
          { "label_key" => "imports.slices.canon_rules", "created" => 3, "skipped" => [ "O-I1" ] }
        ]
      )
    end

    def import_source
      StoryInterchange::Import.new(File.join(@source_root, "synthetic-universe"), owner: @operator)
    end
end
