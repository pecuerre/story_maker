require "test_helper"
require "fileutils"
require "tmpdir"

# A Document reads its file only when it stays inside the source tree, so a link
# that leaves the tree cannot become prose even when the reader is handed the
# path directly.
class StoryInterchangeDocumentTest < ActiveSupport::TestCase
  setup do
    @temporary_directory = Dir.mktmpdir("story-interchange-document-test")
    @root = File.join(@temporary_directory, "source")
    FileUtils.mkdir_p(@root)
  end

  teardown do
    FileUtils.remove_entry(@temporary_directory) if File.directory?(@temporary_directory)
  end

  test "reads a file inside the source tree" do
    path = File.join(@root, "chapter.md")
    File.write(path, "---\ntitle: A chapter\n---\n\n# A chapter\n")

    document = StoryInterchange::Document.load(path, root: @root)

    assert_nil document.parse_error
    assert_equal "A chapter", document.title
  end

  test "refuses a file linked outside the source tree" do
    outside = File.join(@temporary_directory, "outside.md")
    File.write(outside, "# Outside\n")
    path = File.join(@root, "chapter.md")
    File.symlink(outside, path)

    document = StoryInterchange::Document.load(path, root: @root)

    assert_match(/resolves outside the source directory and is not read/, document.parse_error)
    assert_empty document.body
    assert_nil document.title
  end

  test "reports a missing file as unreadable" do
    document = StoryInterchange::Document.load(File.join(@root, "missing.md"), root: @root)

    assert_match(/could not be read/, document.parse_error)
  end
end
