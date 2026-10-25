require "application_system_test_case"

class CharacterKnowledgeTest < ApplicationSystemTestCase
  test "a writer adds a knowledge change from the Character details page" do
    user = users(:user_one)
    universe = universes(:universe_one)
    character = characters(:character_one)

    sign_in_via_form(user)
    visit universe_character_path(universe_slug: universe.slug, id: character)

    assert_selector "h1", text: character.name
    assert_selector "#character-knowledge-heading", text: "What this character knows"

    collection_path = universe_character_character_knowledges_path(
      universe_slug: universe.slug, character_id: character
    )
    within "form[action='#{collection_path}']" do
      fill_in "When", with: "After the warning"
      fill_in "What they learn", with: "The north road is watched."
      select characters(:character_two).name, from: "From whom"
      check "Does this change their plan?"
      click_button "Save knowledge record"
    end
    assert_text "Knowledge record added."
    assert_text "After the warning"
    assert_text "The north road is watched."
    assert_text characters(:character_two).name
    assert_text "Yes"
  end
end
