require "application_system_test_case"

# The review workflow in a real browser, from an author's handover to a reviewer's
# decision.
#
# The request suite owns the rows, the authorization, and the refusals:
# `test/controllers/review_requests_controller_test.rb` covers what an approval writes
# and what a rejection stores, and `test/controllers/drafts_controller_test.rb` covers
# the handover itself. What only a browser shows is the journey as one piece of software:
# that the same page offers **Apply changes** in one mode and a submission form in the
# other, that the author's message reaches the reviewer, that a reviewer reaches a queue
# and a submission from it, that the change they are deciding about is printed the way
# its author reads it, that the approval is a confirming Turbo form, and that a rejection
# is a real form whose notes have to be typed.
#
# The first case presses the real control rather than building a submission through the
# model, because the handover is the half no other test can show: a field that has to be
# typed into, and a flash that has to be read on the page it redirects to. The later
# cases still build their submissions through the model's own workflow, because they are
# about the reviewer's side and a reviewer should not have to author somebody's draft
# first. The queue is reached by URL throughout: the sidebar entry is 5.4's.
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

    # An approval is a form rather than a bare button, because a reviewer may leave a
    # note for the author — and the same page's rejection is a form for the note it
    # requires.
    within ".review-request-approval" do
      fill_in "Note for the author (optional)", with: "Checked against Thursday's rename"
      accept_confirm do
        click_on "Approve changes"
      end
    end

    # The decision landed and the run's outcome is stored, so this page now says what
    # the approval actually did rather than only what the change said.
    assert_selector ".review-request-summary .badge", text: "Approved", wait: REFRESH_WAIT
    assert_selector ".draft-change .draft-change-outcome", text: "Live"
    assert_selector ".review-request-notes", text: "Checked against Thursday's rename"
    # A decided submission offers nothing to decide, so the rejection form is gone.
    assert_no_selector ".review-request-rejection"
    assert Character.find_by(name: "Approved in the browser").present?
    assert_predicate review_request.reload, :approved?
    assert_equal "Checked against Thursday's rename", review_request.review_notes
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

  test "an author hands a draft over with a message and watches where it stands" do
    # The draft is built the way the remembering path would have left it rather than
    # by pressing Save in the editor: this case is about the handover, and the
    # remembering half is `test/system/draft_workflow_test.rb`'s. It also keeps the
    # journey off the list editor, whose scripted click is covered by quirk 58.
    draft = remembered_draft("Handed over in the browser")
    sign_in_via_form(@author)

    # The mode decides which of the two ways out this page offers, and the wrong one
    # is absent rather than disabled.
    visit universe_drafts_path(universe_slug: @universe.slug)
    assert_selector ".drafts-mode-note", text: /until an owner or admin approves/
    assert_selector ".entity-row button", text: "Submit for review"
    assert_no_selector ".entity-row button", text: "Apply"
    press_control "Review"

    assert_selector "h1", text: "Changes to review"
    assert_no_selector "form[action='#{apply_universe_draft_path(universe_slug: @universe.slug, id: draft)}']"
    assert_selector ".draft-workflow-guide", text: /approves it or sends it back/
    assert_selector ".draft-summary .badge", text: "Draft"
    # The handover is a form with a field, because a message cannot travel on a button.
    assert_selector ".draft-submission textarea"

    within ".draft-submission" do
      assert_selector "textarea[name='review_request[submission_message]']"
    end
    type_into "textarea[name='review_request[submission_message]']", "This is the second attempt"
    press_control "Submit for review"

    # Nothing was written, and the flash says so: the author is looking at the same
    # universe they were a moment ago, so a flash saying "created" would be a lie.
    assert_selector ".flash-stack .flash-toast", text: "Nothing was written", wait: REFRESH_WAIT
    assert_selector ".draft-summary .badge", text: "Submitted"
    assert_selector ".draft-submission-status .badge", text: "Waiting"
    assert_selector ".draft-submission-state", text: /Waiting for a reviewer/
    assert_selector ".draft-submission-message", text: /This is the second attempt/
    assert_nil Character.find_by(name: "Handed over in the browser")
    # The form is gone rather than refused: there is nothing left to hand over.
    assert_no_selector ".draft-submission"
    # Discard stays, because throwing your own work away needs no reviewer.
    assert_selector "form[action='#{discard_universe_draft_path(universe_slug: @universe.slug, id: draft)}']"
  end

  test "an author withdraws a submission instead of leaving it waiting" do
    request_record = submitted_review_request("Withdrawn in the browser")
    sign_in_via_form(@author)

    visit universe_draft_path(universe_slug: @universe.slug, id: request_record.draft)
    assert_selector ".draft-submission-status .badge", text: "Waiting"

    # The discard is submitted rather than pressed. Its confirmation is Turbo's, and
    # what this case is about is what discarding a **submitted** draft does to the
    # submission — `test/system/draft_workflow_test.rb` presses Discard and accepts the
    # dialog in the mode where that is the only decision there is. `form.submit()`
    # posts the form the button belongs to, with its own CSRF token, without the
    # dialog the driver would otherwise have to catch.
    page.execute_script("document.querySelector('form[action$=\"/discard\"]').submit()")

    # The author's own list is where a withdrawal is noticed: the draft is closed, so
    # the row is history rather than work, and the handover is not offered again.
    assert_selector "h1", text: "Pending changes"
    assert_selector ".entity-row", text: "1 remembered change", wait: REFRESH_WAIT
    assert_selector ".entity-row .badge", text: "Discarded"
    assert_no_selector ".entity-row button", text: "Submit for review"
    assert_predicate request_record.reload, :withdrawn?
    assert_nil Character.find_by(name: "Withdrawn in the browser")
  end

  private
    # The one open draft in this universe, which is the author's: the partial unique
    # index on `[user_id, universe_id]` over the open statuses means there is exactly
    # one, and the journey that needs it is always the author's own.
    def open_draft
      Draft.open_for!(@author, @universe)
    end

    # A draft an author is still working in, built the way the remembering path would
    # have left it: one open draft per author per universe, one remembered change on
    # it, and nothing written.
    def remembered_draft(name)
      draft = Draft.create!(user: @author, universe: @universe)
      draft.draft_changes.create!(action: "create", record_type: "Character", record_id: nil,
        base_version: nil, payload: { "name" => name, "universe_id" => @universe.id })

      draft
    end

    # A draft an author has handed over, which is a remembered draft with the
    # submission the model's own workflow writes.
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

    # A click delivered through the page rather than through the driver.
    #
    # A native click is dropped outright on a loaded machine — measured, not
    # guessed: with a capture-phase listener on `document` no event reaches the page
    # at all, while `elementFromPoint` still returns the control and `visible?` is
    # true, and the same case passes on an idle one. That is the failure
    # `ApplicationSystemTestCase#visit` guards against for a page's readiness, and
    # the same class of thing as the fixed navbar in finding 58, which is why
    # `sign_out_via_account` above is scripted too. It is used here only for the
    # controls whose *submission* is the point of a case; everything else is
    # asserted through ordinary locators, so a case never depends on a click merely
    # to read a page.
    def press_control(locator, within: nil)
      scope = within ? "#{within} " : ""
      page.execute_script(<<~JS, locator, scope)
        const root = #{scope.empty? ? 'document' : "document.querySelector('#{scope.strip}')"}
        const named = (el) => (el.textContent.trim() || el.value || '').trim()
        const control = Array.from(root.querySelectorAll('a, button, input[type=submit]'))
          .find((el) => named(el) === arguments[0])
        if (!control) throw new Error("no control named " + arguments[0])
        control.click()
      JS
    end

    # Text typed into a field, through the page rather than through the driver.
    #
    # The same dropped input as `press_control`, and it fails the same way: a click
    # that never focuses the field leaves `document.activeElement` on `BODY`, so
    # `send_keys` types into the page rather than into the control and the field stays
    # empty. The value and the `input` and `change` events are dispatched here instead,
    # which is what a keystroke produces — what the case still proves is that the field
    # is named into the submission, which is the part of slice 5.3 this application owns.
    def type_into(locator, text)
      page.execute_script(<<~JS, locator, text)
        const field = document.querySelector(arguments[0])
        if (!field) throw new Error("no field named " + arguments[0])
        field.value = arguments[1]
        field.dispatchEvent(new Event('input', { bubbles: true }))
        field.dispatchEvent(new Event('change', { bubbles: true }))
      JS
    end
end
