require "test_helper"

class SceneTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  test "can be found by its normalized fixture slug" do
    scene = scenes(:scene_one)

    assert_equal "scene-one", scene.slug
    assert_equal scene, Scene.scene_one
  end

  test "requires a story" do
    scene = Scene.new(name: "Orphan")

    assert_not scene.valid?
    assert_includes scene.errors[:story], "must exist"
  end

  test "requires a title" do
    scene = Scene.new(story: @story, name: "")

    assert_not scene.valid?
    assert_includes scene.errors[:name], "can't be blank"
  end

  test "a title-only scene is valid" do
    assert Scene.create!(story: @story, name: "Unfinished scene")
  end

  test "resolves its universe through its story" do
    assert_equal universes(:universe_one), scenes(:scene_one).universe
    assert_nil Scene.new(name: "Orphan").universe
  end

  test "positions are independent flat integers without an ordering parent" do
    assert_not Scene.column_names.include?("parent_id")
    assert_equal [ 0, 1, 2 ], @story.scenes.reorder(:position, :id).pluck(:position)
  end

  test "a story owns and cascades its scenes" do
    assert_includes @story.scenes, scenes(:scene_one)
    assert_not_includes stories(:story_alt).scenes, scenes(:scene_one)

    assert_difference("Scene.count", -1) do
      stories(:story_alt).destroy!
    end
  end

  test "scenes are only reachable through their own universe" do
    assert_equal [ scenes(:scene_one), scenes(:scene_two), scenes(:scene_three) ],
      universes(:universe_one).scenes.where(story: stories(:story_one)).reorder(:position, :id).to_a
    assert_empty universes(:universe_two).scenes
  end
end
