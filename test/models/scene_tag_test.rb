require "test_helper"

class SceneTagTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  test "requires a name and belongs to a story" do
    scene_tag = SceneTag.new(story: @story)

    assert_not scene_tag.valid?
    assert_includes scene_tag.errors[:name], "can't be blank"
  end

  test "rejects a parent from another story" do
    scene_tag = SceneTag.new(story: @story, name: "Child", parent: scene_tags(:scene_tag_three))

    assert_not scene_tag.valid?
    assert_includes scene_tag.errors[:parent], "must belong to the same story"
  end

  test "rejects a descendant as parent" do
    root = SceneTag.create!(story: @story, name: "Root")
    child = SceneTag.create!(story: @story, name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end

  test "belongs to a story instead of a universe" do
    scene_tag = scene_tags(:scene_tag_one)

    assert_equal @story, scene_tag.story
    assert_equal universes(:universe_one), scene_tag.story.universe
    assert_not scene_tag.respond_to?(:universe)
  end

  test "has optional scoped scene assignments" do
    scene = scenes(:scene_one)
    scene_tag = scene_tags(:scene_tag_one)

    assert_equal [ scene_tag, scene_tags(:scene_tag_two) ], scene.scene_tags.order(:position, :id).to_a
    assert_equal [ scene ], scene_tag.scenes.to_a

    scene.scene_tag_ids = []
    assert_empty scene.reload.scene_tags
    assert_empty scene_tag.reload.scenes
  end

  test "rejects a scene tag from another story on either side" do
    scene = scenes(:scene_one)
    foreign_tag = scene_tags(:scene_tag_three)

    assert_not scene.update(scene_tag_ids: [ foreign_tag.id ])
    assert_includes scene.errors[:scene_tags], "must belong to the same story"
    assert_equal [ scene_tags(:scene_tag_one), scene_tags(:scene_tag_two) ], scene.reload.scene_tags.to_a

    assert_not foreign_tag.update(scene_ids: [ scene.id ])
    assert_includes foreign_tag.errors[:scenes], "must belong to the same story"

    foreign_tag.scene_ids = [ "0" ]
    assert_not foreign_tag.valid?
    assert_includes foreign_tag.errors[:scenes], "must exist"
  end

  test "deleting a scene tag leaves its scenes valid and untagged" do
    scene = scenes(:scene_one)

    assert_difference("SceneTag.count", -1) do
      scene_tags(:scene_tag_two).destroy!
    end

    assert_equal [ scene_tags(:scene_tag_one) ], scene.reload.scene_tags.to_a
    assert scene.persisted?
  end

  test "deleting a parent removes child assignments without deleting the scene" do
    root = @story.scene_tags.create!(name: "Disposable root")
    child = @story.scene_tags.create!(name: "Disposable child", parent: root)
    scene = @story.scenes.create!(name: "Scene with temporary tags")
    scene.scene_tags << child

    assert_difference("SceneTag.count", -2) do
      root.destroy!
    end

    assert scene.reload.persisted?
    assert_empty scene.scene_tags
  end
end
