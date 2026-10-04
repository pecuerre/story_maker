require "application_system_test_case"

# The review workflow in a real browser, from an author's handover to a reviewer's
# decision.
#
# The request suite owns the rows, the authorization, and the refusals:
# `test/controllers/review_requests_controller_test.rb` covers what an approval writes
# and what a rejection stores. What only a browser shows is the journey as one piece of
# software — that a reviewer reaches a queue and a submission from it, that the change
# they are deciding about is printed the way its author reads it, that the approval is a
# confirming Turbo form, and that a rejection is a real form whose notes have to be typed.
#
# The submissions here are built through the model's own workflow rather than pressed,
# because pressing **Submit for review** is slice 5.3's control and this slice is not
# claiming it works. The queue is reached by URL for the same reason: the sidebar entry
# is 5.4's.
class ReviewWorkflowTest < ApplicationSystemTestCase
  setup do
    @owner = users(:user_one)
    @author = users(:user_two)
    @universe = universes(:universe_one)
    @universe.update!(collaboration_mode: "github")
  end

  test "a reviewer approves a submission and the change becomes live" do
    review_request = submitted_review_request("Approved in the browser")
    sign_in_via_form(@owner)

    visit universe_review_requests_path(universe_slug: @universe.slug)

    # The queue names what the author asked for and who asked for it: a reviewer reads
    # who is waiting before they read what for.
    assert_selector "h1", text: "Review requests"
    assert_selector ".entity-row", text: "1 remembered change from User Two"
    click_on "Review"

    assert_selector "h1", text: "Changes to review"
    # The change is printed through the draft's own partial, so a reviewer reads a
    # remembered value exactly as its author reads it.
    assert_selector ".draft-change .entity-title", text: "New Character"
    assert_selector ".draft-change .entity-description", text: "Approved in the browser"
    assert_nil Character.find_by(name: "Approved in the browser")

    accept_confirm do
      click_on "Approve changes"
    end

    # The decision landed and the run's outcome is stored, so this page now says what
    # the approval actually did rather than only what the change said.
    assert_selector ".review-request-summary .badge", text: "Approved", wait: REFRESH_WAIT
    assert_selector ".draft-change .draft-change-outcome", text: "Live"
    # A decided submission offers nothing to decide, so the rejection form is gone.
    assert_no_selector ".review-request-rejection"
    assert Character.find_by(name: "Approved in the browser").present?
    assert_predicate review_request.reload, :approved?
  end

  test "a reviewer rejects a submission and the author gets their draft back" do
    review_request = submitted_review_request("Rejected in the browser")
    sign_in_via_form(@owner)

    visit universe_review_request_path(universe_slug: @universe.slug, id: review_request)

    # A rejection is a form rather than a confirmation, because notes are required and a
    # dialog could not hold them.
    within ".review-request-rejection" do
      fill_in "Why are you rejecting it?", with: "This name is the old one"
      click_button "Reject and hand the draft back"
    end

    assert_selector ".review-request-summary .badge", text: "Rejected", wait: REFRESH_WAIT
    assert_selector ".review-request-notes", text: "This name is the old one"
    assert_nil Character.find_by(name: "Rejected in the browser")

    # The author's own page says the draft is theirs to edit again, with its change
    # still on it: a rejection is somebody else's decision, not a deletion.
    sign_out_via_account
    sign_in_via_form(@author)
    visit universe_drafts_path(universe_slug: @universe.slug)

    assert_selector ".entity-row", text: "1 remembered change"
    assert_selector ".entity-row .badge", text: "Draft"
    assert_equal 1, review_request.draft.reload.draft_changes.count
  end

  test "a reviewer who runs into a conflict chooses before anything is written" do
    character = characters(:character_one)
    review_request = submitted_review_request("Renamed in the browser", character)
    sign_in_via_form(@owner)

    visit universe_review_request_path(universe_slug: @universe.slug, id: review_request)

    # Somebody else renames the record after the author remembered the change, which is
    # what `base_version` is there to notice.
    character.update!(name: "Renamed by somebody else")

    accept_confirm do
      click_on "Approve changes"
    end

    # The approval is refused until it is told what to do, and the page that asks
    # replaces the one the reviewer was on.
    assert_selector "h1", text: "Conflicts to resolve", wait: REFRESH_WAIT
    assert_selector ".draft-conflict-state", text: "Changed elsewhere"
    assert_selector ".draft-conflict-mine", text: "Renamed in the browser"
    assert_selector ".draft-conflict-theirs", text: "Renamed by somebody else"

    within ".draft-conflict" do
      click_button "Apply mine"
    end

    assert_selector ".review-request-summary .badge", text: "Approved", wait: REFRESH_WAIT
    assert_selector ".flash-stack .flash-toast", text: "1 remembered change is now live"
    assert_equal "Renamed in the browser", character.reload.name
    assert_predicate review_request.reload, :approved?
  end

  private
    # A draft an author has handed over, built the way the remembering path would have
    # left it: one open draft per author per universe, one pending request on it.
    def submitted_review_request(name, character = nil)
      draft = Draft.create!(user: @author, universe: @universe)
      draft.draft_changes.create!(
        character ? { action: "update", record_type: "Character", record_id: character.id,
          base_version: DraftChange.capture_base_version(character), payload: { "name" => name } }
        : { action: "create", record_type: "Character", record_id: nil, base_version: nil,
          payload: { "name" => name, "universe_id" => @universe.id } }
      )

      draft.submit!
    end

    # The account menu's own control, which is a `button_to` inside a fixed navbar —
    # `test/system/settings_start_page_test.rb` reaches it the same way.
    def sign_out_via_account
      click_button "Account"
      page.execute_script("document.querySelector('form.button_to button').click()")
      assert_selector "h1", text: "Sign in"
      assert_equal new_session_path, current_path
    end
end
