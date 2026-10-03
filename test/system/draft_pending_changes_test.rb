require "application_system_test_case"

# The reader's pending work, in a real browser.
#
# The request suite owns the rows and the badges (`draft_pending_list_test.rb` and
# `draft_pending_panel_test.rb`) and the model owns the answers
# (`draft_preview_test.rb`). What only a browser shows is the journey: an author
# who remembers a create sees it appear in the list they typed it into, sees it
# badged, sees the same fact in the sidebar from every page, and — the part that is
# really only a browser's — watches the rows disappear when the draft is applied.
class DraftPendingChangesTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  test "a remembered create appears in the list it was typed into, badged, and is gone once applied" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)

    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Remembered in the list"
      click_button "Save character"
    end

    # The Characters workspace answers JSON, so the row can only appear once the
    # page has been reloaded — and reloading is what an author does when they want
    # to see what they just typed. The row is badged rather than live, and it has
    # no menu, because there is no record for a menu to act on.
    visit universe_characters_path(universe_slug: @universe.slug)

    within ".draft-pending-row", text: "Remembered in the list" do
      assert_text "Draft"
      assert_no_selector ".row-actions"
      assert_no_selector "a"
    end

    # The sidebar answers the same question on a page with no list of its own, and
    # leads to the draft where the change can be applied.
    within "aside.right-sidebar" do
      assert_selector ".draft-pending-panel .draft-pending-change", text: "New Character"
      assert_selector ".draft-pending-panel .draft-pending-summary", text: "1 pending change"
      click_on "Pending changes"
    end

    click_on "Review"
    accept_confirm do
      click_on "Apply changes"
    end

    # Applying turns the pending row into a live one: the badge goes, and the
    # controls arrive with the id that the remembered create never had.
    visit universe_characters_path(universe_slug: @universe.slug)

    within ".entity-row", text: "Remembered in the list" do
      assert_no_selector ".draft-pending-badge"
      assert_selector ".row-actions"
    end
    assert_no_selector ".draft-pending-row"

    within "aside.right-sidebar" do
      assert_selector ".draft-pending-panel .draft-pending-summary", text: "No pending changes yet"
    end
  end

  test "a remembered edit badges the row without changing it" do
    sign_in_via_form(@user)
    character = characters(:character_one)
    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".list-group-item", text: character.name) do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      fill_in "Name", with: "Renamed but not applied"
      click_button "Save character"
    end

    visit universe_characters_path(universe_slug: @universe.slug)

    # The stored name is what the list shows. A row rewritten with the author's
    # unapplied values would be a second answer about what is in the universe, and
    # a reader who saw it would have no way to know their edit was not saved.
    within ".entity-row", text: character.name do
      assert_selector ".draft-pending-badge", text: "Pending edit"
    end
    assert_no_selector ".entity-row .entity-title", text: "Renamed but not applied"

    within "aside.right-sidebar" do
      assert_selector ".draft-pending-change", text: character.name
    end
  end

  test "a remembered delete leaves the record on the page, badged as going" do
    sign_in_via_form(@user)
    character = characters(:character_one)
    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".list-group-item", text: character.name) do
      find("button[aria-expanded='false']").click
      accept_confirm { click_button "Delete" }
    end

    visit universe_characters_path(universe_slug: @universe.slug)

    # The delete has not been applied, so the record is still here — and a row
    # that vanished would be a lie about the universe.
    within ".entity-row", text: character.name do
      assert_selector ".draft-pending-badge", text: "Pending deletion"
    end
  end

  test "a direct universe shows neither a badge nor a panel" do
    @universe.update!(collaboration_mode: "direct")
    sign_in_via_form(@user)

    visit universe_characters_path(universe_slug: @universe.slug)

    assert_no_selector ".draft-pending-badge"
    within "aside.right-sidebar" do
      assert_no_selector ".draft-pending-panel"
      assert_no_selector "a.sidebar-link", text: "Pending changes"
    end
  end

  test "a guest sees neither a badge nor a panel" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)
    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Remembered by a writer"
      click_button "Save character"
    end
    visit universe_characters_path(universe_slug: @universe.slug)
    assert_selector ".draft-pending-row"

    # Somebody else's pending work is not a page this reader may read, and it is
    # not shown to them either: a badge on a shared record would announce that
    # somebody is mid-edit.
    within "nav.navbar" do
      find(".dropdown-toggle").click
      click_on "Log out"
    end
    visit universe_characters_path(universe_slug: @universe.slug)

    assert_no_selector ".draft-pending-badge"
    assert_no_selector ".draft-pending-row"
    within "aside.right-sidebar" do
      assert_no_selector ".draft-pending-panel"
    end
  end
end
