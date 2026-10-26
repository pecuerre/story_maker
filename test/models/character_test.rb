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

  test "pronouns and aliases are optional and join the searchable profile" do
    character = Character.create!(universe: universes(:universe_one), name: "Ariadne",
      at_a_glance: "Thread-puller", pronouns: "she/her", aliases: "The Gate, Ari")

    assert_equal "Thread-puller she/her The Gate, Ari", character.search_description

    blank = Character.create!(universe: universes(:universe_one), name: "Unnamed")
    assert_nil blank.pronouns
    assert_nil blank.aliases
  end

  test "faction memberships are optional and can include more than one faction" do
    character = characters(:character_one)

    character.update!(factions: [ factions(:faction_one), factions(:faction_two) ])

    assert_equal [ factions(:faction_one), factions(:faction_two) ].sort_by(&:id), character.factions.sort_by(&:id)
  end

  test "does not assign a faction from another universe" do
    character = characters(:character_one)
    character.factions = [ factions(:faction_other_universe) ]

    assert_not character.valid?
    assert_includes character.errors[:factions], I18n.t("shared.errors.same_scope.universe")
  end

  test "faction reads hide a corrupt cross-universe join" do
    character = characters(:character_one)
    foreign_faction = factions(:faction_other_universe)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO characters_factions (character_id, faction_id)
      VALUES (#{character.id}, #{foreign_faction.id})
    SQL

    assert_not_includes character.factions, foreign_faction
  end

  test "soft-deleting a character also soft-deletes its knowledge records" do
    character = characters(:character_one)
    knowledge = character_knowledges(:knowledge_one)

    character.soft_delete

    assert knowledge.reload.deleted?
  end

  test "hard-destroying a Character cleans up knowledge records even if already soft-deleted" do
    character = characters(:character_one)
    knowledge = character_knowledges(:knowledge_one)
    knowledge.soft_delete

    character.destroy!

    assert_not CharacterKnowledge.with_deleted.exists?(knowledge.id)
  end

  test "hard-destroying a source Character clears that optional attribution" do
    source = characters(:character_two)
    knowledge = character_knowledges(:knowledge_one)

    source.destroy!

    assert_nil knowledge.reload.source_character_id
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
