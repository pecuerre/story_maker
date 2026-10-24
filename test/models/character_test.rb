require "test_helper"

class CharacterTest < ActiveSupport::TestCase
  test "requires a name" do
    character = Character.new(universe: universes(:universe_one), character_tags: [ character_tags(:character_tag_one) ])

    assert_not character.valid?
    assert_includes character.errors[:name], "can't be blank"
  end

  test "allows a character without tags" do
    assert Character.create!(universe: universes(:universe_one), name: "Untagged")
  end

  test "soft-deleting a turn speaker preserves its attributed lines for restore" do
    character = characters(:character_three)
    turn = scene_dialogue_turns(:turn_one)

    character.soft_delete

    assert SceneDialogueTurn.exists?(turn.id)
    assert_nil turn.reload.speaker, "the soft-deleted Character is hidden by its default scope"

    character.restore

    assert_equal character, turn.reload.speaker
  end

  test "hard-destroying a turn speaker removes its turn without deleting the Element" do
    character = characters(:character_three)
    element = scene_elements(:dialogue_one)
    turn_id = scene_dialogue_turns(:turn_one).id
    scene_dialogue_turns(:turn_one).soft_delete

    assert_difference -> { SceneDialogueTurn.with_deleted.count }, -1 do
      character.destroy!
    end

    assert SceneElement.exists?(element.id)
    assert_not SceneDialogueTurn.with_deleted.exists?(turn_id)
  end
end
