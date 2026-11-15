require "test_helper"

# The containment rule the importer applies to every path: a resolved path is
# inside the source tree when it is the root itself or sits below it, and a
# sibling whose name merely starts with the same characters is not.
class StoryInterchangeSourceTreeTest < ActiveSupport::TestCase
  test "inside? accepts the root and its children" do
    assert StoryInterchange::SourceTree.inside?("/srv/sources", "/srv/sources")
    assert StoryInterchange::SourceTree.inside?("/srv/sources", "/srv/sources/universe/README.md")
  end

  test "inside? refuses a sibling that shares the root's prefix" do
    assert_not StoryInterchange::SourceTree.inside?("/srv/sources", "/srv/sources-other/README.md")
  end

  test "inside? treats the filesystem root as containing every absolute path" do
    assert StoryInterchange::SourceTree.inside?("/", "/etc/passwd")
  end
end
