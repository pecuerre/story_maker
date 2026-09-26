require "test_helper"

class SceneLocationTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @link = scene_locations(:scene_location_one)
  end

  test "requires a scene and a location" do
    link = SceneLocation.new(role: "setting")

    assert_not link.valid?
    assert_includes link.errors[:scene], "must exist"
    assert_includes link.errors[:location], "must exist"
  end

  test "resolves its universe through its scene" do
    assert_equal universes(:universe_one), @link.universe
    assert_nil SceneLocation.new.universe
  end

  test "the role is optional and free text" do
    assert_equal "setting", @link.role
    assert_nil scene_locations(:scene_location_two).role
    assert SceneLocation.create!(scene: @scene,
      location: universes(:universe_one).locations.create!(name: "Free text"), role: "left behind, more or less")
  end

  test "a blank role means no role rather than an empty annotation" do
    link = SceneLocation.new(scene: @scene,
      location: universes(:universe_one).locations.create!(name: "Blank"), role: "   ")

    assert link.valid?
    assert_nil link.role
  end

  test "a location can only be linked to a scene once" do
    duplicate = SceneLocation.new(scene: @scene, location: @link.location)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:location_id], "is already in this scene"
  end

  test "rejects a location from another universe" do
    outsider = universes(:universe_two).locations.create!(name: "Outsider")
    link = SceneLocation.new(scene: @scene, location: outsider)

    assert_not link.valid?
    assert_includes link.errors[:location], "must belong to the scene's universe"
  end

  test "the database refuses a duplicate link the model rejected first" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      SceneLocation.connection.execute(
        "INSERT INTO scene_locations (scene_id, location_id, created_at, updated_at) " \
        "VALUES (#{@scene.id}, #{@link.location_id}, datetime('now'), datetime('now'))"
      )
    end
  end

  test "a scene owns and cascades its presence links" do
    assert_includes @scene.scene_locations, @link

    assert_difference("SceneLocation.count", -2) do
      @scene.destroy!
    end
  end

  test "deleting a location removes its presence links but never a scene" do
    location = @link.location

    assert_no_difference("Scene.count") do
      location.destroy!
    end

    assert_equal 1, @scene.scene_locations.count
    assert_not_includes @scene.scene_locations.pluck(:location_id), location.id
  end

  test "the same location may be linked to different scenes" do
    other = stories(:story_alt).scenes.create!(name: "Alt scene two")

    assert SceneLocation.create!(scene: other, location: @link.location)
  end
end
