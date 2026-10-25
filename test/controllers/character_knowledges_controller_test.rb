require "test_helper"

class CharacterKnowledgesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @knowledge = character_knowledges(:knowledge_one)
    sign_in_as(users(:user_one))
  end

  def collection_path(character = @character)
    universe_character_character_knowledges_path(universe_slug: @universe.slug, character_id: character)
  end

  def member_path(knowledge = @knowledge)
    universe_character_character_knowledge_path(universe_slug: @universe.slug,
      character_id: @character, id: knowledge)
  end

  test "creates a knowledge record for the selected character" do
    assert_difference("CharacterKnowledge.count", 1) do
      post collection_path, params: { character_knowledge: {
        when_text: "At the bridge", what_learned: "The guard knows the route.",
        source_character_id: characters(:character_two).id, changes_plan: "1"
      } }
    end

    assert_redirected_to universe_character_path(universe_slug: @universe.slug, id: @character)
    entry = CharacterKnowledge.order(:id).last
    assert_equal @character, entry.character
    assert_equal characters(:character_two), entry.source_character
    assert_predicate entry, :changes_plan?
  end

  test "updates and soft-deletes a knowledge record under its character" do
    patch member_path, params: { character_knowledge: { what_learned: "The bridge is watched." } }

    assert_redirected_to universe_character_path(universe_slug: @universe.slug, id: @character)
    assert_equal "The bridge is watched.", @knowledge.reload.what_learned

    assert_no_difference("CharacterKnowledge.with_deleted.count") do
      delete member_path
    end
    assert_redirected_to universe_character_path(universe_slug: @universe.slug, id: @character)
    assert_predicate @knowledge.reload, :deleted?
  end

  test "rejects a knowledge source from another universe" do
    assert_no_difference("CharacterKnowledge.count") do
      post collection_path, params: { character_knowledge: {
        when_text: "At the bridge", what_learned: "The guard knows the route.",
        source_character_id: characters(:character_other_universe).id
      } }
    end

    assert_response :unprocessable_content
    assert_includes response.body, "must belong to the same universe"
  end

  test "cannot address a character through a different universe's URL" do
    post universe_character_character_knowledges_path(
      universe_slug: @universe.slug, character_id: characters(:character_other_universe)
    ), params: { character_knowledge: { when_text: "Later", what_learned: "Something." } }

    assert_response :not_found
  end
end
