require "test_helper"

class CharacterKnowledgeTest < ActiveSupport::TestCase
  test "requires when and what was learned" do
    knowledge = CharacterKnowledge.new(universe: universes(:universe_one), character: characters(:character_one))

    assert_not knowledge.valid?
    assert_includes knowledge.errors[:when_text], "can't be blank"
    assert_includes knowledge.errors[:what_learned], "can't be blank"
  end

  test "rejects a source character from another universe" do
    knowledge = CharacterKnowledge.new(
      universe: universes(:universe_one),
      character: characters(:character_one),
      source_character: characters(:character_other_universe),
      when_text: "After the meeting",
      what_learned: "The plan changed."
    )

    assert_not knowledge.valid?
    assert_includes knowledge.errors[:source_character], I18n.t("shared.errors.same_scope.universe")
  end
end
