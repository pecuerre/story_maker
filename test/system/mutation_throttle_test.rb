require "application_system_test_case"

# What a refused mutation looks like in the browser, which no request test can
# show: the modal the author is looking at either explains the refusal itself or
# says nothing at all.
#
# A JSON-only controller answers an over-budget mutation with a bare `429` and an
# empty body (ADR 0028, `docs/adr/0028-per-universe-mutation-budget.md`), so the
# sentence on screen is the editor's own. The request tests in
# `test/controllers/mutation_throttle_test.rb` prove the status and the budget;
# this file proves the author is told what happened and can retry without
# retyping.
class MutationThrottleSystemTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    # One mutation per minute, so the second submit in this test is over budget
    # whatever else the browser does.
    @universe.update!(mutation_limit: 1)
  end

  test "a throttled create says to wait, keeps the modal open, and saves nothing" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded

    # This one is inside the budget, and refreshes the list like any other save.
    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Inside the budget"
      click_button "Save character"
    end
    assert_selector ".entity-row .entity-title", text: "Inside the budget", wait: REFRESH_WAIT

    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Over the budget"
      click_button "Save character"

      # The refusal must not read like a rejected value: nothing about the form
      # is wrong, and an author told to fix the record would fix nothing.
      assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "making changes too quickly"
      assert_field "Name", with: "Over the budget", exact: true
    end

    assert_no_selector ".entity-row .entity-title", text: "Over the budget"
  end
end
