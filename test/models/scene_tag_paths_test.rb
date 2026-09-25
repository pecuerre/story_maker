require "test_helper"

class SceneTagPathsTest < ActiveSupport::TestCase
  test "builds root-first paths from one ordered tag list" do
    root = scene_tags(:scene_tag_one)
    child = scene_tags(:scene_tag_two)

    paths = SceneTagPaths.build([ root, child ])

    assert_equal "Scene tag one", paths.label_for(root)
    assert_equal "Scene tag one / Scene tag two", paths.label_for(child)
    assert_equal [ [ "Scene tag one", root.id ], [ "Scene tag one / Scene tag two", child.id ] ], paths.choices
  end

  test "returns nil for an unknown tag id" do
    paths = SceneTagPaths.build(scene_tags(:scene_tag_one))

    assert_nil paths.label_for(0)
  end
end
