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

  test "the three per-group ceilings save from the same form and clear individually" do
    # What only a browser shows is the group loop's own output: three fields whose
    # labels are distinct sentences, and the empty field the admin submits to remove
    # one ceiling while the two beside it keep theirs (ADR 0029).
    universe = universes(:universe_one)
    sign_in_via_form(users(:user_one))

    visit edit_universe_path(universe)
    assert_field "Photo uploads per minute", with: Universe::MUTATION_GROUP_LIMITS[:photo].to_s
    assert_field "Access changes per minute", with: Universe::MUTATION_GROUP_LIMITS[:membership].to_s
    assert_field "Discussion replies per minute", with: Universe::MUTATION_GROUP_LIMITS[:discussion].to_s

    fill_in "Photo uploads per minute", with: "3"
    fill_in "Discussion replies per minute", with: ""
    click_button "Update Universe"

    assert_selector ".alert-success"
    assert_equal 3, universe.reload.photo_mutation_limit
    assert universe.reload.mutation_group_unlimited?(:discussion)
    assert_equal Universe::MUTATION_GROUP_LIMITS[:membership], universe.reload.membership_mutation_limit

    # A cleared field reopens blank rather than printing the default the reader
    # would substitute for it.
    visit edit_universe_path(universe)
    assert_field "Discussion replies per minute", with: ""
  end
end
