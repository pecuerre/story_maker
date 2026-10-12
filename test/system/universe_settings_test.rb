require "application_system_test_case"

# The universe settings form in a browser, which is where an admin raises, lowers, or
# removes this universe's mutation budget (ADR 0028).
#
# `test/controllers/universes_controller_test.rb` proves the parameters, the stored
# column, and who may send them. What only a browser shows is the control itself: the
# field opens on the default rather than blank, and clearing it is a submission the
# browser accepts rather than a value it refuses — a `min` on a number field constrains
# the numbers that are there, and an empty field is not one of them.
class UniverseSettingsTest < ApplicationSystemTestCase
  test "an admin changes the limit and sees the universe saved with it" do
    universe = universes(:universe_one)
    sign_in_via_form(users(:user_one))

    visit edit_universe_path(universe)
    assert_field "Changes per minute", with: Universe::DEFAULT_MUTATION_LIMIT.to_s

    fill_in "Changes per minute", with: "5"
    click_button "Update Universe"

    assert_selector ".alert-success"
    assert_equal 5, universe.reload.mutation_limit

    visit edit_universe_path(universe)
    assert_field "Changes per minute", with: "5"
  end

  test "clearing the field removes the limit instead of leaving it at nothing" do
    universe = universes(:universe_one)
    universe.update!(mutation_limit: 2)
    sign_in_via_form(users(:user_one))

    visit edit_universe_path(universe)
    fill_in "Changes per minute", with: ""
    click_button "Update Universe"

    assert_selector ".alert-success"
    assert universe.reload.mutations_unlimited?
  end
end
