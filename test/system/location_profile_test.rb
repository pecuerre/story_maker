require "application_system_test_case"

# The Location profile is edited through the tree's browser-built modal, so what
# only a browser can show is that the serialized textareas exist, accept text, and
# save it through the JSON mutation path to the record and its details page.
class LocationProfileTest < ApplicationSystemTestCase
  test "a Location's profile answers save from the tree editor and show on its page" do
    user = users(:user_one)
    universe = universes(:universe_one)
    location = locations(:location_one)

    sign_in_via_form(user)
    visit universe_locations_path(universe_slug: universe.slug)
    assert_stimulus_loaded

    click_row_menu_action "li[data-node-id='#{location.id}'] > .taxonomy-row", "Edit"
    within ".modal.show" do
      # A field from each end of the profile, by its editor label.
      fill_in "Sensory: sight", with: "Gray light through a high window"
      fill_in "Control and access: restrictions", with: "Only the wardens hold the key"
      click_button "Save changes"
    end

    assert_no_selector ".modal.show"
    location.reload
    assert_equal "Gray light through a high window", location.sensory_sight
    assert_equal "Only the wardens hold the key", location.access_restrictions

    visit universe_location_path(universe_slug: universe.slug, id: location)

    # The label's styling uppercases it, so the match is case-insensitive rather
    # than asserting the stylesheet's rendering.
    assert_selector ".detail-fact dt", text: /Sensory: sight/i
    assert_selector ".detail-fact dd", text: "Gray light through a high window"
    assert_selector ".detail-fact dt", text: /Control and access: restrictions/i
    assert_selector ".detail-fact dd", text: "Only the wardens hold the key"
    # Every answer is optional, so the untouched ones say so rather than render blank.
    assert_selector ".detail-fact dd", text: "Not recorded yet."
  end
end
