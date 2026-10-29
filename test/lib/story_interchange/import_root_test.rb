require "test_helper"
require "fileutils"
require "tmpdir"

# The browser-facing boundary: a folder name is turned into a path only when it
# is a real child of the configured root. Everything else — a separator, `..`,
# an absolute path, a dot-file, a symlink leading out — is nil.
class StoryInterchangeImportRootTest < ActiveSupport::TestCase
  setup do
    @temporary_directory = Dir.mktmpdir("story-interchange-root-test")
    @root = File.join(@temporary_directory, "sources")
    FileUtils.mkdir_p(File.join(@root, "the-fifth-cabinet"))
    FileUtils.mkdir_p(File.join(@root, ".hidden"))
    File.write(File.join(@root, "notes.md"), "not a source")
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
  end

  test "lists only the real child directories" do
    assert_equal [ "the-fifth-cabinet" ], import_root.folders
  end

  test "resolves a child folder by name" do
    assert_equal File.join(@root, "the-fifth-cabinet"), import_root.path_for("the-fifth-cabinet")
  end

  test "refuses a name that is not a single child segment" do
    [ "", "..", "../outside", "/etc", "nested/source", "nested\\source", ".hidden", "missing" ].each do |name|
      assert_nil import_root.path_for(name), "expected #{name.inspect} to be refused"
    end
  end

  test "refuses a symlink that resolves outside the root" do
    outside = File.join(@temporary_directory, "outside")
    FileUtils.mkdir_p(outside)
    File.symlink(outside, File.join(@root, "escape"))

    assert_nil import_root.path_for("escape")
    assert_not_includes import_root.folders, "escape"
  end

  test "a symlink that stays inside the root keeps its selected name" do
    File.symlink(File.join(@root, "the-fifth-cabinet"), File.join(@root, "alias"))

    assert_equal File.join(@root, "alias"), import_root.path_for("alias")
    assert_includes import_root.folders, "alias"
  end

  test "an unconfigured root offers nothing" do
    root = StoryInterchange::ImportRoot.new(nil)

    assert_not root.configured?
    assert_empty root.folders
    assert_nil root.path_for("anything")
  end

  test "a configured path that does not exist is not usable" do
    root = StoryInterchange::ImportRoot.new(File.join(@temporary_directory, "missing"))

    assert_not root.configured?
    assert_empty root.folders
    assert_nil root.path_for("anything")
  end

  private
    def import_root
      StoryInterchange::ImportRoot.new(@root)
    end
end
