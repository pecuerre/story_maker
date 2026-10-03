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
end
