require "application_system_test_case"

# Browser regressions for the shared modal JSON flow
# (`app/javascript/controllers/modal_form_controller.js`). The old form submitted
# HTML to JSON-only endpoints: the record was saved, the response was 406, the
# errors were never shown, and a delete left a stale row in the DOM. Each test
# below pins one half of the replacement contract: the JSON submission succeeds,
# a 422 is explained in the modal, a request that never lands is reported, and a
# delete really removes the row and its counts.
class ModalJsonFlowTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
  end

  test "a modal create saves through JSON and refreshes the list and its counts" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    before = @universe.characters.count

    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Modal character"
      fill_in "Description", with: "Saved as JSON."
      click_button "Save character"
    end

    # The mutation is a fetch followed by a same-URL refresh, so the row, the page
    # count, and the sidebar count all come from one server render. The refresh is
    # a full navigation, so the first assertion after it waits longer than the
    # default: a slow machine must not turn a passing refresh into a failure.
    assert_selector ".entity-row .entity-title", text: "Modal character", wait: REFRESH_WAIT
    assert_selector ".entity-row .entity-description", text: "Saved as JSON."
    within ".page-header" do
      assert_selector ".badge", text: (before + 1).to_s
    end
    within "nav[aria-label='Universe and story navigation']" do
      assert_selector ".sidebar-count", text: (before + 1).to_s
    end
    assert_no_selector ".modal.show"
    assert_no_selector ".invalid-feedback"
  end

  test "a record-level 422 keeps the modal open, explains itself, and recovers" do
    sign_in_via_form(@user)
    visit universe_events_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    existing = events(:event_one)

    # An event with no title, date, or relation is rejected by the model, and no
    # field in the modal is required, so this is a reachable 422.
    click_button "Add event"
    within ".modal.show" do
      fill_in "Description", with: "Nothing identifies this event."
      click_button "Save event"

      assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "The change could not be saved"
      assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "must have a title, a date, or a relation to another event"
      assert_field "Description", with: "Nothing identifies this event."
    end
    # A rejected save must not close the modal.
    assert_selector ".modal.show"
    assert_no_selector ".entity-row .entity-description", text: "Nothing identifies this event."
    assert_equal 2, @universe.events.count
    assert_equal existing, @universe.events.find_by(title: "The beginning")

    # The same form then succeeds, so the failure above was reported, not fatal.
    within ".modal.show" do
      fill_in "Title", with: "Event from a rejected form"
      click_button "Save event"
    end
    assert_selector ".entity-row .entity-title", text: "Event from a rejected form", wait: REFRESH_WAIT
    assert_equal 3, @universe.events.count
    assert_equal "Nothing identifies this event.", Event.order(:id).last.description
  end

  test "a field error is rendered on the control that caused it" do
    sign_in_via_form(@user)
    visit universe_events_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    event = events(:event_one)

    within_row(event.display_string) do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end

    within ".modal.show" do
      # The model rejects an event that points at itself and keys the error on the
      # association, so the message belongs on the foreign-key control.
      select event.display_string, from: "Happens before"
      click_button "Save event"

      assert_selector "[data-modal-form-error-for='before_event']", text: "cannot be itself", visible: :visible
      assert_selector "select#event_before_event_id[aria-invalid='true']"
      assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "Happens before cannot be itself"
      # The summary takes focus, so the reason is announced instead of only shown.
      assert_selector "[data-modal-form-target='errors']:focus"
    end
    assert_selector ".modal.show"
    assert_nil event.reload.before_event_id
  end

  test "a request that never reaches the server is reported and leaves the form usable" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    before = @universe.characters.count

    break_fetch
    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Never sent"
      click_button "Save character"

      assert_selector "[data-modal-form-target='errors'] .alert-danger", text: "The change could not be sent"
      # The form is not left pending: the button works again and the value is kept.
      assert_selector "input[type='submit'][data-modal-form-target='submit']:not([disabled])"
      assert_field "Name", with: "Never sent"
    end
    assert_equal before, @universe.characters.count
  end

  test "a delete that never reaches the server keeps the row and says why" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    character = characters(:character_two)

    break_fetch
    within_row(character.name) do
      find("button[aria-expanded='false']").click
      accept_confirm { click_button "Delete" }
    end

    assert_selector ".mutation-status .alert-danger", text: "The record could not be deleted"
    assert_selector ".entity-row .entity-title", text: character.name
    assert Character.exists?(character.id)
  end

  test "deleting a row removes it and its counts instead of leaving a stale row" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    character = characters(:character_two)
    before = @universe.characters.count

    within_row(character.name) do
      find("button[aria-expanded='false']").click
      accept_confirm { click_button "Delete" }
    end

    assert_no_selector ".entity-row .entity-title", text: character.name
    within ".page-header" do
      assert_selector ".badge", text: (before - 1).to_s
    end
    within "nav[aria-label='Universe and story navigation']" do
      assert_selector ".sidebar-count", text: (before - 1).to_s
    end
    assert_nil Character.find_by(id: character.id)
    assert_no_selector ".dropdown-menu.show"
  end

  test "clearing the last tag in the modal actually clears the assignment" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    character = characters(:character_one)
    assert_equal [ character_tags(:character_tag_one).id ], character.character_tag_ids

    within_row(character.name) do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      assert_selector "[data-ts-item]", text: character_tags(:character_tag_one).name
      find("[data-ts-item] [title='Remove']").click
      assert_no_selector "[data-ts-item]"
      click_button "Save character"
    end
    # The save replaces the page, so wait for the refreshed render before looking
    # at the row: a node resolved against the old document would be stale.
    assert_no_selector ".modal.show"
    within_row(character.name) do
      assert_no_selector ".taxonomy-tag"
    end
    assert_empty character.reload.character_tag_ids
  end

  test "a long value in a narrow viewport still saves and stays readable" do
    sign_in_via_form(@user)
    page.current_window.resize_to(390, 844)
    visit universe_items_path(universe_slug: @universe.slug)
    assert_stimulus_loaded
    name = "Item of unusually long descriptive name that has to wrap inside a narrow modal"

    click_button "Add item"
    within ".modal.show" do
      fill_in "Name", with: name
      fill_in "Description", with: "Saved from a 390px viewport."
      click_button "Save item"
    end

    assert_selector ".entity-row .entity-title", text: name, visible: :visible, wait: REFRESH_WAIT
    within ".page-header" do
      assert_selector ".badge", text: @universe.items.count.to_s
    end
  end

  private
    # A list row is matched by its own list-group item, never by the surrounding
    # `.entity-list`, which contains the same text and would silently widen the
    # scope to every row on the page.
    def within_row(name, &block)
      within first(".list-group-item", text: name), &block
    end

    # Replaces `fetch` with a rejection so the network-failure branch of the
    # modal controller can be exercised in a real browser. The stub lives in the
    # test's own browser session, which is quit after the test.
    def break_fetch
      page.execute_script(<<~JS)
        window.fetch = () => Promise.reject(new TypeError("Failed to fetch"))
      JS
    end
end
