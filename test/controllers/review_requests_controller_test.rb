require "test_helper"

# What a reviewer can do about somebody else's submitted draft.
#
# The request suite owns the rows and the authorization, which is the half of this
# workflow no browser shows: that the queue is the owner and the admins and nobody else,
# that a submission in another universe is a 404 rather than a row somebody's decision
# leaked, that an approval is the author's own apply in full — conflicts, stored
# outcomes, the same flash — and that a decision cannot be taken twice.
#
# What only a browser shows is the journey, in `test/system/review_workflow_test.rb`.
class ReviewRequestsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @owner = users(:user_one)
    @author = users(:user_two)
    @character = characters(:character_one)
    sign_in_as(@owner)
  end

  # The queue

  test "the queue lists what is waiting first and what has been decided behind it" do
    waiting = review_request(submitted_change)
    decided = review_request(submitted_change, status: "approved", reviewed_by: @owner, by: another_author)

    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_response :success
    # Read in the order the page renders them: a reviewer comes here to decide
    # something, and history sorted above the pending submission would push it down.
    assert_equal [ waiting.id, decided.id ],
      css_select(".entity-row a").map { |link| link["href"].split("/").last.to_i }
    assert_equal [ "Waiting", "Approved" ],
      css_select(".review-request-status").map { |badge| badge.text.strip }
  end

  test "a row names the author who submitted and how much they are asking for" do
    review_request(submitted_change, submitted_change)

    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-title", text: /2 remembered changes from User Two/
    assert_select ".entity-description", text: /Submitted/
  end

  test "a decided row says who decided it and what they said" do
    review_request(submitted_change, status: "rejected", reviewed_by: @owner, notes: "The name is the old one")

    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".review-request-decision", text: /by User One/
    assert_select ".review-request-decision", text: /The name is the old one/
  end

  test "a submission from another universe is not in this queue" do
    elsewhere = review_request(submitted_change, universe: universes(:universe_two))

    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".entity-row", count: 0
    assert_select "a[href=?]", universe_review_request_path(universe_slug: @universe.slug, id: elsewhere), count: 0
  end

  test "a reviewer with nothing waiting is told the queue is empty" do
    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-state", text: /Nothing is waiting for a decision/
  end

  # The authorization boundary
  #
  # Every action here asks for `admin`, which the shared universe policy decides from
  # the controller's name. Read access is deliberately not enough: the queue names every
  # author who has submitted something, and what happens to it is the owner's call.

  test "a plain writer cannot read or answer the queue" do
    request_record = review_request(submitted_change, universe: contributed_universe)

    get universe_review_requests_url(universe_slug: contributed_universe.slug)
    assert_response :forbidden

    get universe_review_request_url(universe_slug: contributed_universe.slug, id: request_record)
    assert_response :forbidden

    assert_no_difference -> { Character.count } do
      post approve_universe_review_request_url(universe_slug: contributed_universe.slug, id: request_record)
      post reject_universe_review_request_url(universe_slug: contributed_universe.slug, id: request_record),
        params: { review_request: { review_notes: "Not mine to decide" } }
    end

    assert_response :forbidden
    assert_predicate request_record.reload, :pending?
    assert_predicate request_record.draft.reload, :submitted?
  end

  test "an admin who is not the owner reads and answers the queue" do
    admin = users(:user_two)
    administered = Universe.create!(owner: @owner, name: "Administered", slug: "administered", private: true)
    UniverseMembership.create!(user: admin, universe: administered, access_level: "admin")
    request_record = review_request(submitted_change, universe: administered)
    sign_out
    sign_in_as(admin)

    get universe_review_requests_url(universe_slug: administered.slug)

    assert_response :success
    assert_select ".entity-row", count: 1

    post approve_universe_review_request_url(universe_slug: administered.slug, id: request_record)

    assert_redirected_to universe_review_request_url(universe_slug: administered.slug, id: request_record)
    assert_predicate request_record.reload, :approved?
    assert_equal admin, request_record.reviewed_by
  end

  test "a guest is sent to sign in rather than shown what is waiting" do
    # A review request has an author, so there is no guest-readable version of this
    # queue in any universe: the sign-in is asked for before the universe is even
    # resolved, which is the same order every other page that needs a person uses.
    hidden = Universe.create!(owner: @owner, name: "Hidden", slug: "hidden", private: true)
    review_request(submitted_change, universe: hidden)
    sign_out

    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_redirected_to new_session_url

    get universe_review_requests_url(universe_slug: hidden.slug)

    assert_redirected_to new_session_url
  end

  # One submission

  test "the page states every change the submitted draft remembers" do
    request_record = review_request(
      remember_update("Renamed by a submission"),
      remember_create("A remembered character")
    )

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".draft-change", count: 2
    assert_select ".draft-change .entity-description", text: /Renamed by a submission/
    assert_select ".draft-change .entity-title", text: "New Character"
    assert_select ".review-request-submitted-by", text: /Submitted by User Two/
  end

  test "a submission in another universe does not exist from this one" do
    request_record = review_request(submitted_change, universe: universes(:universe_two))

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :not_found
  end

  # Approving
  #
  # An approval is the author's own apply, in full. That is asserted here rather than
  # assumed: the same applier, the same conflict rows, the same stored outcome.

  test "approving writes the changes through the live mutation path and records the decision" do
    request_record = review_request(remember_create("Approved in the request suite"))

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal I18n.t("drafts.flash.applied", count: 1), flash[:notice]
    assert Character.find_by(name: "Approved in the request suite").present?
    assert_predicate request_record.reload, :approved?
    assert_equal @owner, request_record.reviewed_by
    assert_predicate request_record.draft.reload, :applied?
    outcome = request_record.draft.draft_changes.sole.outcome
    assert_predicate outcome, :written?
    assert_equal "Approved in the request suite", outcome.draft_change.payload["name"]
  end

  test "an approval may carry a note for the author, and an empty box says nothing" do
    noted = review_request(remember_create("Approved with a note"))

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: noted),
      params: { review_request: { review_notes: "Applied over the rename from Thursday" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: noted)
    assert_equal "Applied over the rename from Thursday", noted.reload.review_notes
    assert_predicate noted, :approved?

    # And the note is the one place an author can read what a reviewer decided, so it
    # has to be on the page rather than only in the row.
    get universe_review_request_url(universe_slug: @universe.slug, id: noted)
    assert_select ".review-request-notes", text: /Applied over the rename from Thursday/

    plain = review_request(remember_create("Approved without a note"), by: another_author)

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: plain),
      params: { review_request: { review_notes: "" } }

    # An empty box is not something a reviewer said, so it is stored as nothing at all
    # rather than as an empty string that reads back as a decision.
    assert_nil plain.reload.review_notes
  end

  test "a note survives the conflict question it was written before" do
    request_record = review_request(remember_update("Renamed by a submission"))
    remembered = request_record.draft.draft_changes.sole
    @character.update!(name: "Somebody else got here first")

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "Chose mine over Thursday's rename" } }

    assert_response :unprocessable_content
    # The note is part of this approval, and the approval is reached twice: the field
    # comes back with the question rather than asking for the sentence a second time.
    assert_select "textarea[name=?]", "review_request[review_notes]", text: "Chose mine over Thursday's rename"

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { resolutions: { remembered.id.to_s => "mine" },
        review_request: { review_notes: "Chose mine over Thursday's rename" } }

    assert_equal "Chose mine over Thursday's rename", request_record.reload.review_notes
  end

  test "the approval page offers no control once the decision has been made" do
    request_record = review_request(submitted_change, status: "approved", reviewed_by: @owner)

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".review-request-rejection", count: 0
    assert_select "form[action=?]", approve_universe_review_request_path(universe_slug: @universe.slug,
      id: request_record), count: 0
  end

  test "approving twice is refused rather than writing a second copy" do
    request_record = review_request(remember_create("Only once"))

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_response :see_other

    assert_no_difference -> { Character.count } do
      post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    end

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal I18n.t("review_requests.flash.decided"), flash[:alert]
    assert_equal 1, Character.where(name: "Only once").count
  end

  test "a conflict stops the approval and is asked about instead" do
    request_record = review_request(remember_update("Renamed by a submission"))
    remembered = request_record.draft.draft_changes.sole
    @character.update!(name: "Somebody else got here first")

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :unprocessable_content
    assert_select ".draft-conflict", count: 1
    assert_select ".draft-conflict .badge", text: "Changed elsewhere"
    # Both halves of the choice, under the same labels: an answer nobody can evaluate is
    # an answer pressed at random.
    assert_select ".draft-conflict-mine", text: /Renamed by a submission/
    assert_select ".draft-conflict-theirs", text: /Somebody else got here first/
    assert_equal "Somebody else got here first", @character.reload.name
    assert_predicate request_record.reload, :pending?

    # The answers come back to the same action, which is the one waiting for them, and
    # they are keyed by the change rather than by the record it names.
    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { resolutions: { remembered.id.to_s => "mine" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal "Renamed by a submission", @character.reload.name
    assert_predicate request_record.reload, :approved?
    assert_predicate remembered.reload.outcome, :written?
  end

  test "an answer of theirs leaves the record alone and still closes the draft" do
    request_record = review_request(remember_update("Renamed by a submission"))
    remembered = request_record.draft.draft_changes.sole
    @character.update!(name: "Somebody else got here first")

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { resolutions: { remembered.id.to_s => "theirs" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal I18n.t("drafts.flash.kept_theirs", count: 1), flash[:notice]
    assert_equal "Somebody else got here first", @character.reload.name
    assert_predicate request_record.draft.reload, :applied?
    assert_predicate request_record.reload, :approved?
  end

  test "an answer is only honoured for a change that still conflicts on this request" do
    request_record = review_request(remember_update("Renamed by a submission"))
    remembered = request_record.draft.draft_changes.sole

    # A change that is not in conflict carries a stray answer that must never be treated
    # as an instruction to write over somebody else's record.
    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { resolutions: { remembered.id.to_s => "theirs" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal "Renamed by a submission", @character.reload.name
    assert_predicate request_record.reload, :approved?
  end

  # A submission the applier cannot read at all
  #
  # The refusal is in words, not a 404: a reviewer reading "this submission does not
  # exist" for a submission sitting in their own queue would look for the wrong problem.

  test "a submission holding a change the applier cannot read is refused in words and writes nothing" do
    request_record = review_request(remember_create("A remembered character", extra: { "wibble" => 1 }))

    post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :unprocessable_content
    assert_select ".draft-damaged", text: /cannot be applied as it stands/
    assert_select ".draft-damaged", text: /wibble/
    assert_nil Character.find_by(name: "A remembered character")
    # The run wrote nothing, so the author's way out is untouched: the draft is still
    # open and the submission is still waiting for a decision.
    assert_predicate request_record.draft.reload, :submitted?
    assert_predicate request_record.reload, :pending?
  end

  test "the page states the damage before the reviewer presses anything" do
    request_record = review_request(remember_create("A remembered character", extra: { "wibble" => 1 }))

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".draft-damaged", text: /wibble/
  end

  # Rejecting

  test "rejecting hands the draft back to its author, with the notes and the reviewer stored" do
    request_record = review_request(submitted_change)

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "The name is the old one" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal I18n.t("review_requests.flash.rejected"), flash[:notice]
    assert_predicate request_record.reload, :rejected?
    assert_equal @owner, request_record.reviewed_by
    assert_equal "The name is the old one", request_record.review_notes
    # The draft comes back as working work, with its changes: a rejection is somebody
    # else's decision about the author's draft, and the author edits it again.
    assert_predicate request_record.draft.reload, :draft?
    assert_equal 1, request_record.draft.draft_changes.count
  end

  test "a rejection has to say why, and the reason is shown beside the field" do
    request_record = review_request(submitted_change)

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "" } }

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /must say why the submission was rejected/
    # The submission is still waiting, and the controls that answer it are still there:
    # a page that had decided the review would have nothing left to offer.
    assert_predicate request_record.reload, :pending?
    assert_predicate request_record.draft.reload, :submitted?
    assert_select "form[action=?]", reject_universe_review_request_path(universe_slug: @universe.slug,
      id: request_record), count: 1
  end

  test "the notes a rejection carried are what the reviewer still reads afterwards" do
    request_record = review_request(submitted_change, status: "rejected", reviewed_by: @owner,
      notes: "The name is the old one")

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".review-request-notes", text: /The name is the old one/
  end

  test "a decided submission cannot be rejected again" do
    request_record = review_request(submitted_change, status: "rejected", reviewed_by: @owner,
      notes: "Already answered")

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "Changed my mind" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal I18n.t("review_requests.flash.decided"), flash[:alert]
    assert_equal "Already answered", request_record.reload.review_notes
  end

  test "a submission the applier cannot read is still rejectable" do
    # A rejection never interprets a remembered change, so refusing it must not be the
    # reviewer's only option: the damaged change is the author's problem to fix, and
    # keeping it would block the whole queue behind one bad row.
    request_record = review_request(remember_create("A remembered character", extra: { "wibble" => 1 }))

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "This one cannot be read" } }

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_predicate request_record.reload, :rejected?
    assert_predicate request_record.draft.reload, :draft?
  end

  # What the author said with the handover
  #
  # Slice 5.3 stores a submission message, and a stored message nobody can read is a
  # column that costs a write and says nothing. It is the context for reading the
  # diffs, so it is printed above them and labelled as the author's words.

  test "the review page shows the author's message above the changes" do
    request_record = review_request(submitted_change, message: "This is the second attempt")

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".review-request-submission-message", text: /The author wrote/
    assert_select ".review-request-submission-message", text: /This is the second attempt/
  end

  test "a submission with no message says nothing rather than an empty box" do
    request_record = review_request(submitted_change)

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".review-request-submission-message", count: 0
  end

  # Withdrawing
  #
  # The author's own answer, and the fourth status in the queue. Both decisions must
  # refuse it: a withdrawn submission's draft was discarded, and `DraftApplier` asks
  # whether a draft is open nowhere, so approving one would write the changes live
  # after the author threw them away.

  test "a withdrawn submission is history, and cannot be approved or rejected" do
    request_record = review_request(submitted_change)
    request_record.withdraw!

    assert_no_difference -> { Character.count } do
      post approve_universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    end

    assert_redirected_to universe_review_request_url(universe_slug: @universe.slug, id: request_record)
    assert_equal I18n.t("review_requests.flash.decided"), flash[:alert]
    assert_predicate request_record.reload, :withdrawn?
    assert_predicate request_record.draft.reload, :discarded?

    post reject_universe_review_request_url(universe_slug: @universe.slug, id: request_record),
      params: { review_request: { review_notes: "Changed my mind" } }

    assert_equal I18n.t("review_requests.flash.decided"), flash[:alert]
    assert_predicate request_record.reload, :withdrawn?
  end

  test "a withdrawn submission says so instead of naming a reviewer who never saw it" do
    request_record = review_request(submitted_change)
    request_record.withdraw!

    get universe_review_request_url(universe_slug: @universe.slug, id: request_record)

    assert_response :success
    assert_select ".review-request-summary .badge", text: "Withdrawn"
    # Dated by the draft's closure rather than the submission: a reviewer is being told
    # when the author took it back, not when they handed it over.
    assert_select ".review-request-withdrawn",
      text: /#{Regexp.escape(I18n.l(request_record.draft.closed_at, format: :short))}/
    assert_select ".review-request-withdrawn", text: /Nothing was written/
    # Nothing to decide, so neither form is offered.
    assert_select ".review-request-decisions", count: 0

    get universe_review_requests_url(universe_slug: @universe.slug)

    assert_select ".review-request-withdrawn", text: /author discarded this draft/
  end

  private
    # A third person, for the one case that needs two authors in one universe: the
    # partial unique index on `[user_id, universe_id]` refuses two *open* drafts for one
    # author, so a decided submission and a pending one cannot be the same author's.
    def another_author
      @another_author ||= User.create!(name: "User Three", email_address: "three@example.com", password: "password")
    end

    def review_request(*changes, status: "pending", reviewed_by: nil, notes: nil,
      universe: nil, by: nil, message: nil)
      universe ||= @universe
      draft = Draft.create!(user: by || @author, universe: universe)
      changes.each { |attributes| draft.draft_changes.create!(attributes) }
      draft.submit!(message: message).tap do |review_request|
        review_request.update!(status: status, reviewed_by: reviewed_by, review_notes: notes) unless status == "pending"
      end
    end

    # A universe whose owner is somebody else, where this reader may write but not
    # administer. It has to be private: a public universe grants every signed-in user
    # write regardless of what a membership row says, so the membership is the only
    # thing that can express "contributor, not reviewer".
    def contributed_universe
      @contributed_universe ||= begin
        universe = Universe.create!(owner: @author, name: "Contributed", slug: "contributed", private: true)
        UniverseMembership.create!(user: @owner, universe: universe, access_level: "write")
        universe
      end
    end

    def submitted_change
      remember_create("A remembered character")
    end

    # No scope column in the payload: the applier places a create in the draft's own
    # universe, which is the only universe these requests are ever applied in.
    def remember_create(name = "A remembered character", extra: {})
      { action: "create", record_type: "Character", record_id: nil, base_version: nil,
        payload: { "name" => name }.merge(extra) }
    end

    def remember_update(name)
      { action: "update", record_type: "Character", record_id: @character.id,
        base_version: DraftChange.capture_base_version(@character), payload: { "name" => name } }
    end
end
