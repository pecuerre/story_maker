require "test_helper"

class SceneCharacterTest < ActiveSupport::TestCase
  setup do
    @scene = scenes(:scene_one)
    @link = scene_characters(:scene_character_one)
  end

  test "requires a scene and a character" do
    link = SceneCharacter.new(role: "setting")

    assert_not link.valid?
    assert_includes link.errors[:scene], "must exist"
    assert_includes link.errors[:character], "must exist"
  end

  test "resolves its universe through its scene" do
    assert_equal universes(:universe_one), @link.universe
    assert_nil SceneCharacter.new.universe
  end

  test "the role is optional and free text" do
    assert_equal "setting", @link.role
    assert_nil scene_characters(:scene_character_two).role
    assert SceneCharacter.create!(scene: @scene, character: universes(:universe_one).characters.create!(name: "Free text"),
      role: "carries the box, reluctantly")
  end

  test "a blank role means no role rather than an empty annotation" do
    link = SceneCharacter.new(scene: @scene, character: universes(:universe_one).characters.create!(name: "Blank"),
      role: "   ")

    assert link.valid?
    assert_nil link.role
  end

  test "a character can only be linked to a scene once" do
    duplicate = SceneCharacter.new(scene: @scene, character: @link.character)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:character_id], "is already in this scene"
  end

  test "rejects a character from another universe" do
    outsider = universes(:universe_two).characters.create!(name: "Outsider")
    link = SceneCharacter.new(scene: @scene, character: outsider)

    assert_not link.valid?
    assert_includes link.errors[:character], "must belong to the scene's universe"
  end

  test "the database refuses a duplicate link the model rejected first" do
    assert_raises(ActiveRecord::RecordNotUnique) do
      SceneCharacter.connection.execute(
        "INSERT INTO scene_characters (scene_id, character_id, created_at, updated_at) " \
        "VALUES (#{@scene.id}, #{@link.character_id}, datetime('now'), datetime('now'))"
      )
    end
  end

  test "a scene owns and cascades its presence links" do
    assert_includes @scene.scene_characters, @link

    assert_difference("SceneCharacter.count", -2) do
      @scene.destroy!
    end
  end

  test "deleting a character removes its presence links but never a scene" do
    character = @link.character

    assert_no_difference("Scene.count") do
      character.destroy!
    end

    assert_equal 1, @scene.scene_characters.count
    assert_not_includes @scene.scene_characters.pluck(:character_id), character.id
  end

  test "the same character may be linked to different scenes" do
    other = stories(:story_alt).scenes.create!(name: "Alt scene two")

    assert SceneCharacter.create!(scene: other, character: @link.character)
  end
end
