require "application_system_test_case"

class RoutesFlowTest < ApplicationSystemTestCase
  test "a writer adds a route and opens its details" do
    user = users(:user_one)
    universe = universes(:universe_one)
    from = locations(:location_one)
    to = locations(:location_two)

    sign_in_via_form(user)
    visit universe_routes_path(universe_slug: universe.slug)
    assert_stimulus_loaded
    click_button "Add route"

    within ".modal.show" do
      fill_in "Name", with: "The north road"
      select from.name, from: "From location"
      select to.name, from: "To location"
      fill_in "Distance", with: "12 leagues"
      fill_in "Travel time", with: "Two days on foot"
      click_button "Save route"
    end

    assert_selector ".entity-row", text: "The north road", wait: REFRESH_WAIT
    assert_selector ".entity-row", text: "12 leagues"
    within find(".entity-row", text: "The north road") do
      click_link "Details"
    end
    assert_text "Two days on foot"
    assert_text from.name
    assert_text to.name
  end
end
