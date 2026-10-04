require "application_system_test_case"

# The draft workflow in a real browser, from a remembered edit to a live record.
#
# The request suite owns the rows and the authorization:
# `test/controllers/draft_mutation_test.rb` covers the remembering half across all
# twenty controllers, and `test/controllers/drafts_controller_test.rb` covers
# reading, applying, and discarding. What only a browser shows is the journey as
# one piece of software — that an editor who is told their change was remembered
# has a link to follow from the very page they were working in, that the draft they
# land on says what the change is, and that pressing **Apply changes** really
# writes it.
#
# The confirmation dialogs are part of that. Applying and discarding are Turbo
# `button_to` forms, and the request suite sends neither a confirmation nor a CSRF
# token, so both are covered nowhere else.
class DraftWorkflowTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "wikipedia")
  end

  test "an editor remembers a change, finds it from the workspace, and applies it" do
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)

    # The ordinary editor, in a universe that remembers instead of writing: the
    # modal's own flow, unchanged.
    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Remembered in the browser"
      fill_in "Description", with: "Not live until it is applied."
      click_button "Save character"
    end

    assert_no_selector ".entity-row .entity-title", text: "Remembered in the browser", wait: REFRESH_WAIT
    assert_nil Character.find_by(name: "Remembered in the browser"),
      "a remembered create must not be written, or applying the draft would write a second copy of it"

    # The right sidebar is where an editor looks for the change they were just told
    # is waiting: the link exists only where a draft can exist, and following it is
    # a page load rather than a write.
    within "aside.right-sidebar" do
      assert_selector "a.sidebar-link", text: "Pending changes"
      click_on "Pending changes"
    end

    # The list is the author's own drafts in this universe, and the one that can
    # still be acted on is the one it leads with.
    assert_selector "h1", text: "Pending changes"
    assert_selector ".entity-row", text: "1 remembered change"
    click_on "Review"

    assert_selector "h1", text: "Changes to review"
    # A remembered create names no record, so its row is titled by the type it
    # would create and shows what the author submitted.
    assert_selector ".draft-change .entity-title", text: "New Character"
    assert_selector ".draft-change .entity-description", text: "Remembered in the browser"

    accept_confirm do
      click_on "Apply changes"
    end

    assert_selector ".draft-summary .badge", text: "Applied", wait: REFRESH_WAIT
    assert_no_selector ".page-actions button", text: "Apply changes"
    assert Character.find_by(name: "Remembered in the browser").present?,
      "the change the author reviewed must be the change that is now live"

    visit universe_characters_path(universe_slug: @universe.slug)
    assert_selector ".entity-row .entity-title", text: "Remembered in the browser", wait: REFRESH_WAIT
  end

  test "an editor throws a draft away instead of applying it" do
    sign_in_via_form(@user)
    character = characters(:character_one)
    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".list-group-item", text: character.name) do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      fill_in "Name", with: "Renamed in the browser"
      click_button "Save character"
    end

    assert_no_selector ".entity-row .entity-title", text: "Renamed in the browser", wait: REFRESH_WAIT
    assert_equal character.name, character.reload.name, "a remembered rename must not be written"

    within "aside.right-sidebar" do
      click_on "Pending changes"
    end
    assert_selector ".entity-row", text: "1 remembered change"
    click_on "Review"

    assert_selector ".draft-change .entity-description", text: "Renamed in the browser"
    assert_selector ".draft-change a[href='#{character.search_url}']"

    accept_confirm do
      click_on "Discard draft"
    end

    # The discarded draft stays in the list as history — a remembered change is
    # append-only, so rejecting the draft is a status and not a deletion — and the
    # row no longer offers anything to do with it.
    assert_selector ".entity-row .badge", text: "Discarded", wait: REFRESH_WAIT
    assert_no_selector ".entity-row button", text: "Discard"
    assert_no_selector ".entity-row button", text: "Apply"
    assert_equal character.name, character.reload.name
  end

  test "an editor who runs into a conflict chooses between their change and what is there" do
    # The one part of conflict resolution a request test cannot show: the apply
    # button is a confirming Turbo form, and the answer is a second form on a
    # page Turbo has to render *in place* — a 422 that redirected, or that
    # answered with a bare 200, would drop the author somewhere else entirely.
    # The request suite sends neither a confirmation nor a CSRF token.
    character = characters(:character_one)
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)

    within first(".list-group-item", text: character.name) do
      find("button[aria-expanded='false']").click
      click_button "Edit"
    end
    within ".modal.show" do
      fill_in "Name", with: "Renamed in the browser"
      click_button "Save character"
    end
    assert_no_selector ".entity-row .entity-title", text: "Renamed in the browser", wait: REFRESH_WAIT

    # Somebody else renames the same record after the change was remembered,
    # which is the conflict `base_version` exists to notice.
    character.update!(name: "Renamed by somebody else")

    within "aside.right-sidebar" do
      click_on "Pending changes"
    end
    assert_selector ".entity-row", text: "1 remembered change"
    click_on "Review"
    accept_confirm do
      click_on "Apply changes"
    end

    # The apply is refused until it is told what to do, and the page that asks
    # replaces the one the author was on.
    assert_selector "h1", text: "Conflicts to resolve", wait: REFRESH_WAIT
    assert_selector ".draft-conflict-state", text: "Changed elsewhere"
    assert_selector ".draft-conflict-mine", text: "Renamed in the browser"
    assert_selector ".draft-conflict-theirs", text: "Renamed by somebody else"

    within ".draft-conflict" do
      click_button "Apply theirs"
    end

    assert_selector ".draft-summary .badge", text: "Applied", wait: REFRESH_WAIT
    # Nothing was written and nothing failed: the choice gets its own sentence
    # rather than being counted as a change the universe refused.
    assert_selector ".flash-stack .flash-toast", text: "left exactly as it is now"
    assert_equal "Renamed by somebody else", character.reload.name,
      "theirs keeps the record as the other editor left it"
  end

  test "an author starts editing, and the universe page says how much is waiting" do
    # The editing session is the one thing here that only a browser shows as a
    # journey: press the control, walk into a workspace, come back, and the page
    # has counted what was remembered in between. The flash that follows stopping
    # is part of it too, because it is what tells an author their pending work did
    # not disappear.
    sign_in_via_form(@user)

    visit universe_path(universe_slug: @universe.slug)
    assert_selector ".page-actions", text: "Start editing"
    assert_selector ".page-actions", text: "No pending changes yet", count: 0

    click_button "Start editing"

    # Entering the session opens the draft, so the count is honest from the first
    # moment rather than appearing only once something has been remembered.
    assert_selector ".page-actions", text: "No pending changes yet"
    assert_selector ".page-actions", text: "Stop editing"
    assert_equal 1, Draft.open_for(@user, @universe).id

    # The claim is per universe and survives navigation, which is the difference
    # between an editing session and a one-page banner.
    visit universe_characters_path(universe_slug: @universe.slug)
    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Counted while editing"
      click_button "Save character"
    end

    visit universe_path(universe_slug: @universe.slug)

    assert_selector ".page-actions", text: "1 pending change"
    assert_selector ".page-actions", text: "Stop editing"

    # The count is a way into the changes, so following it lands on the draft.
    click_on "1 pending change"
    assert_selector "h1", text: "Pending changes"
    assert_selector ".entity-row", text: "1 remembered change"

    visit universe_path(universe_slug: @universe.slug)
    click_button "Stop editing"

    assert_selector ".page-actions", text: "Start editing"
    # Stopping released the session, not the work, and the flash says where it went.
    assert_selector ".flash-stack .flash-toast", text: "1 remembered change is still waiting on your draft"
    assert_equal 1, Draft.open_for(@user, @universe).draft_changes.count
  end

  test "a change made without pressing start editing is still remembered" do
    # The property the whole design rests on, and the reason the control is a claim
    # rather than a switch: an author who never pressed it must still be unable to
    # write straight through a universe that remembers changes.
    sign_in_via_form(@user)
    visit universe_characters_path(universe_slug: @universe.slug)

    assert_no_selector ".page-actions", text: "Stop editing"

    click_button "Add character"
    within ".modal.show" do
      fill_in "Name", with: "Remembered without the toggle"
      click_button "Save character"
    end

    # The Characters workspace answers JSON, so nothing was written and there is
    # nothing on the page to see but the missing row: the draft is where the change
    # went, and the right sidebar is how an editor reaches it. Going there is also
    # how the test waits for the write, because the JSON mutation carries no page
    # change of its own.
    within "aside.right-sidebar" do
      click_on "Pending changes"
    end

    assert_selector ".entity-row", text: "1 remembered change"
    assert_nil Character.find_by(name: "Remembered without the toggle")
  end
end
