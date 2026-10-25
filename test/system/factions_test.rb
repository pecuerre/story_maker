require "application_system_test_case"

class FactionsTest < ApplicationSystemTestCase
  test "the Factions workspace and profile details are browser reachable" do
    user = users(:user_one)
    universe = universes(:universe_one)
    faction = factions(:faction_one)

    sign_in_via_form(user)
    visit universe_factions_path(universe_slug: universe.slug)
    assert_stimulus_loaded
    assert_selector "h1", text: "Factions"
    assert_selector "button[data-action='modal-form#open']", text: "Add faction"
    assert_selector "form[data-modal-form-target='form'] textarea[name='faction[actual_aims]']", visible: :all

    within find(".entity-row", text: faction.name) do
      click_link "Details"
    end

    assert_selector "h1", text: faction.name
    assert_text faction.mission
    assert_text faction.actual_aims
    assert_text faction.structure
    assert_text faction.internal_divisions
    assert_text faction.resources
    assert_text faction.would_never
    assert_text faction.would_absolutely
  end
end
