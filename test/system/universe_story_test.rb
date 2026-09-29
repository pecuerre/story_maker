require "application_system_test_case"

class UniverseStoryTest < ApplicationSystemTestCase
  test "a user can create a universe and story, then open story-scoped sections" do
    sign_in_via_form(users(:user_one))

    visit new_universe_path
    fill_in "Name", with: "System Test Universe"
    click_button "Create Universe"

    assert_selector "h1", text: "System Test Universe"
    assert_selector ".alert-success", text: "Universe was successfully created."
    # The universe page lists its stories directly and keeps an "All stories"
    # link to the full page.
    within ".page-actions" do
      click_link "All stories"
    end

    assert_selector "h1", text: "Stories", wait: 5
    click_link "New story"
    fill_in "Name", with: "System Test Story"
    fill_in "Description", with: "A story created by a system test."
    click_button "Create Story"

    assert_selector "h1", text: "System Test Story"
    assert_selector ".alert-success", text: "Story was successfully created."
    click_link "Open sections"

    assert_selector "h1", text: "Sections"
    assert_match %r{/u/system-test-universe/s/\d+/sections\z}, current_path
  end

  test "a name whose address is taken is refused, and the address field answers it" do
    sign_in_via_form(users(:user_one))

    # "One" derives the address `one`, which the `universe_one` fixture already
    # holds. The refusal is a stated field error on the form, not a 500 page.
    visit new_universe_path
    fill_in "Name", with: "One"
    click_button "Create Universe"

    assert_selector ".alert-danger[role=alert] li", text: "Slug has already been taken"
    assert_equal "One", find("#universe_name").value

    fill_in "Address slug", with: "one-in-another-timeline"
    click_button "Create Universe"

    assert_selector "h1", text: "One"
    assert_match %r{/u/one-in-another-timeline\z}, current_path
  end
end
