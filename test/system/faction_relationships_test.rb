require "application_system_test_case"

class FactionRelationshipsTest < ApplicationSystemTestCase
  test "a directed faction relationship can be created and read in the browser" do
    user = users(:user_one)
    universe = universes(:universe_one)
    from = factions(:faction_one)
    to = factions(:faction_two)

    sign_in_via_form(user)
    visit universe_faction_relationships_path(universe_slug: universe.slug)
    assert_stimulus_loaded
    assert_selector "h1", text: "Faction relationships"
    assert_selector "nav.content-tabs a.active", text: "Relationships"

    click_button "Add relationship"
    within ".modal.show" do
      select from.name, from: "From faction"
      select to.name, from: "To faction"
      fill_in "Name", with: "An explicit direction"
      fill_in "Description", with: "The source faction approaches the other."
      click_button "Save relationship"
    end

    assert_selector ".entity-row .entity-title", text: "An explicit direction", wait: REFRESH_WAIT
    within find(".entity-row", text: "An explicit direction") do
      click_link "Details"
    end

    assert_selector "h1", text: "An explicit direction"
    assert_text from.name
    assert_text to.name
    assert_text "The source faction approaches the other."
  end
end
