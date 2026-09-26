require "test_helper"

class SceneItemTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @link = scene_items(:scene_item_one)
  end

  test "requires a scene and an item" do
    link = SceneItem.new(role: "carries")

    assert_not link.valid?
    assert_includes link.errors[:scene], "must exist"
    assert_includes link.errors[:item], "must exist"
  end

  test "resolves its universe through its scene" do
    assert_equal universes(:universe_one), @link.universe
    assert_nil SceneItem.new.universe
  end

  test "the role is optional and free text" do
    assert_equal "carries", @link.role
    assert_nil scene_items(:scene_item_two).role
    assert SceneItem.create!(scene: @scene, item: universes(:universe_one).items.create!(name: "Free text"),
      role: "on the table, technically")
  end

  test "a blank role means no role rather than an empty annotation" do
    link = SceneItem.new(scene: @scene, item: universes(:universe_one).items.create!(name: "Blank"),
      role: "   ")

    assert link.valid?
    assert_nil link.role
  end

  test "an item can only be linked to a scene once" do
    duplicate = SceneItem.new(scene: @scene, item: @link.item)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:item_id], "is already in this scene"
  end

  test "rejects an item from another universe" do
    outsider = universes(:universe_two).items.create!(name: "Outsider")
    link = SceneItem.new(scene: @scene, item: outsider)

    assert_not link.valid?
    assert_includes link.errors[:item], "must belong to the scene's universe"
  end

  test "the database refuses a duplicate link the model rejected first" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      SceneItem.connection.execute(
        "INSERT INTO scene_items (scene_id, item_id, created_at, updated_at) " \
        "VALUES (#{@scene.id}, #{@link.item_id}, datetime('now'), datetime('now'))"
      )
    end
  end

  test "a scene owns and cascades its presence links" do
    assert_includes @scene.scene_items, @link

    assert_difference("SceneItem.count", -2) do
      @scene.destroy!
    end
  end

  test "deleting an item removes its presence links but never a scene" do
    # A dedicated item so the assertion is about the presence links alone rather
    # than about the hierarchical cleanup its child items also perform.
    item = universes(:universe_one).items.create!(name: "Doomed")
    @scene.scene_items.create!(item: item, role: "carries")
    scenes(:scene_three).scene_items.create!(item: item)

    assert_difference("SceneItem.count", -2) do
      assert_no_difference("Scene.count") do
        item.destroy!
      end
    end

    assert_not_includes @scene.scene_items.pluck(:item_id), item.id
  end

  test "the same item may be linked to different scenes" do
    other = stories(:story_alt).scenes.create!(name: "Alt scene two")

    assert SceneItem.create!(scene: other, item: @link.item)
  end
end
