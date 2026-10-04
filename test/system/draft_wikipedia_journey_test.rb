require "application_system_test_case"

# The whole `wikipedia` journey in one browser pass: start editing, make a change of
# each kind, see them in the lists, apply, and see them live.
#
# `draft_workflow_test.rb` and `draft_pending_changes_test.rb` each walk one half of
# this and assert what that half needs; `draft_journey_test.rb` walks all of it over
# requests. None of them walks it the way an author does, which is *without stopping*
# — one editing session, three kinds of change, one page in between, one apply at the
# end. The seam that matters is between the last remembered change and the apply: a
# journey that remembers three things and writes two of them, or badges a record the
# apply never touched, would pass every test that checks a single step.
class DraftWikipediaJourneyTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  test "an author edits, watches the pending rows, applies once, and sees the universe move" do
    edited = characters(:character_one)
    removed = characters(:character_two)
    sign_in_via_form(@user)

    # **Start editing.** The control on the universe page, which is the journey's
    # only entry point an author has to find deliberately — everything after it
    # works without it.
    visit universe_path(universe_slug: @universe.slug)
    assert_selector ".page-actions", text: "No pending changes yet", count: 0
    click_button "Start editing"
    assert_selector ".page-actions", text: "Stop editing"
    # Entering the session opens the draft, so the count is honest from the first
    # moment rather than appearing only once something has been remembered.
    assert_selector ".page-actions", text: "No pending changes yet"

    # **Make changes of every kind**, in one workspace and one session.
    visit universe_characters_path(universe_slug: @universe.slug)

    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Remembered on the way in"
      click_button "Save character"
    end

    # Each remembered mutation refreshes the page, so the row the next step opens is
    # read from a fresh load rather than a node the previous refresh replaced.
    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".list-group-item", text: edited.name) do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      fill_in "Name", with: "Renamed on the way in"
      click_button "Save character"
    end

    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".list-group-item", text: removed.name) do
      find("button[aria-expanded='false']").click
      accept_confirm { click_button "Delete" }
    end

    assert_nil Character.find_by(name: "Remembered on the way in")
    assert_equal edited.name, edited.reload.name
    assert_predicate removed, :present?

    # **See them in the lists**, which means reloading: the Characters workspace
    # answers JSON, so the page has no way to show the outcome of the last click on
    # its own, and reloading is what an author does to check.
    visit universe_characters_path(universe_slug: @universe.slug)

    within ".draft-pending-row", text: "Remembered on the way in" do
      assert_text "Draft"
    end
    within ".entity-row", text: edited.name do
      assert_selector ".draft-pending-badge", text: "Pending edit"
    end
    within ".entity-row", text: removed.name do
      assert_selector ".draft-pending-badge", text: "Pending deletion"
    end

    # **The sidebar counts them**, and leads to the one place they can be acted on.
    within "aside.right-sidebar" do
      assert_selector ".draft-pending-panel .draft-pending-summary", text: "3 pending changes"
      click_on "Pending changes"
    end

    # **The guidance a first-time author needs** is on the page the flash and the
    # sidebar both send them to, and it says the three steps in the order they meet
    # them rather than describing the controls above it.
    assert_selector ".draft-workflow-guide", text: "How your changes work here"
    assert_selector ".draft-workflow-guide li", count: 3
    assert_selector ".entity-row", text: "3 remembered changes"

    click_on "Review"
    assert_selector "h1", text: "Changes to review"
    # The guide belongs on the draft's page too: the list is where an author finds
    # out something is waiting, and this is where they decide about it.
    assert_selector ".draft-workflow-guide li", count: 3

    # **Apply**, once, with everything on it.
    accept_confirm do
      click_on "Apply changes"
    end

    assert_selector ".draft-summary .badge", text: "Applied", wait: REFRESH_WAIT
    assert_selector ".flash-stack .flash-toast", text: "3 remembered changes are now live"

    # **The history the flash does not keep.** The toast above is the only report of
    # this run that a reader gets once; what an author comes back to is the draft's
    # own page and the list it sits in, so the run has to be readable there too — and
    # each change says what became of it beside the values it carried.
    assert_selector ".draft-history", text: "Applied"
    assert_selector ".draft-history", text: "3 remembered changes are live"
    assert_selector ".draft-change .draft-change-outcome", text: "Live", count: 3

    visit universe_drafts_path(universe_slug: @universe.slug)

    within ".entity-row", text: "3 remembered changes" do
      assert_selector ".draft-history", text: "Applied"
      assert_selector ".draft-history", text: "3 remembered changes are live"
    end

    # **See them live**: the three pending rows are now three records, and each one
    # carries the controls a remembered create never had.
    visit universe_characters_path(universe_slug: @universe.slug)

    assert_no_selector ".draft-pending-row"
    assert_no_selector ".draft-pending-badge"
    within ".entity-row", text: "Remembered on the way in" do
      assert_selector ".row-actions"
    end
    within ".entity-row", text: "Renamed on the way in" do
      assert_selector ".row-actions"
    end
    assert_no_selector ".entity-row", text: removed.name
    assert_equal "Remembered on the way in", Character.find_by(name: "Remembered on the way in").name
    assert_equal "Renamed on the way in", edited.reload.name

    within "aside.right-sidebar" do
      assert_selector ".draft-pending-panel .draft-pending-summary", text: "No pending changes yet"
    end
  end
end
