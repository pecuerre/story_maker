require "test_helper"

# What one author's request for somebody else to apply a draft holds.
#
# The controller tests own who may see and answer a review request; what is only
# answerable here is the model: which statuses a row may hold, that it cannot
# claim a universe or an author its draft does not have, that a rejection has to
# say why and a decision has to say who, that only one review per draft is in
# flight, and that the whole thing goes when the draft does.
class ReviewRequestTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @author = users(:user_one)
    @draft = Draft.create!(user: @author, universe: @universe)
  end

  test "a submission names the draft, the universe, and the author who made it" do
    request = build_request

    assert request.save
    assert_equal @draft, request.draft
    assert_equal @universe, request.universe
    assert_equal @author, request.submitted_by
    # Nobody has looked at it yet, which is what the two nullable columns say.
    assert_nil request.reviewed_by
    assert_nil request.review_notes
  end

  test "requires a draft, a universe, and a submitter" do
    assert_not ReviewRequest.new(universe: @universe, submitted_by: @author).valid?
    assert_not ReviewRequest.new(draft: @draft, submitted_by: @author).valid?
    assert_not ReviewRequest.new(draft: @draft, universe: @universe).valid?
  end

  test "starts life pending, and the pending scope and the predicate agree" do
    request = create_request

    assert_equal ReviewRequest::PENDING, request.status
    assert_predicate request, :pending?
    assert_not_predicate request, :decided?
    assert_includes ReviewRequest.pending, request

    ReviewRequest::STATUSES.each do |status|
      # A decided status needs a reviewer, so the row is given one here rather
      # than refused: this test is about which statuses exist and which of them
      # are still waiting, not about what a decision has to say.
      request.update!(status: status, reviewed_by: users(:user_two), review_notes: "Not this time")

      assert_equal request.pending?, ReviewRequest.pending.where(id: request.id).exists?,
        "`pending` and `pending?` must answer the same question, or a reviewer's queue is not the set " \
        "of rows `pending?` describes"
    end
  end

  test "refuses a status nothing in the application behaves for" do
    # The same reasoning as `Draft::STATUSES` and `Universe::COLLABORATION_MODES`:
    # a review status outside the list is a row no reviewer page can answer and no
    # control can act on, and the reader would find out by watching a button do
    # nothing.
    request = build_request(status: "commented")

    assert_not request.valid?
    assert_includes request.errors[:status], "is not included in the list"
  end

  test "names each stored status rather than leaving callers to compare strings" do
    request = build_request

    assert_predicate request, :pending?
    assert_not_predicate request, :approved?
    assert_not_predicate request, :rejected?

    request.update!(status: "approved", reviewed_by: users(:user_two))
    assert_predicate request, :approved?
    assert_not_predicate request, :pending?
    assert_predicate request, :decided?

    request.update!(status: "rejected", review_notes: "This belongs to another story")
    assert_predicate request, :rejected?
    assert_predicate request, :decided?
  end

  test "a submission cannot claim a universe its draft is not in" do
    # Two columns that disagree are refused rather than resolved. The draft's own
    # universe is what authorized its changes, so a request filed under another
    # one would be reviewed through a scope nobody authorized it against — the
    # same sentence `Discussion` gives for the same disagreement.
    request = build_request(universe: universes(:universe_two))

    assert_not request.valid?
    assert_includes request.errors[:universe], I18n.t("shared.errors.same_scope.universe")
  end

  test "a submission cannot claim an author the draft does not have" do
    # A draft has exactly one author, so the person submitting it is that author.
    # Letting the two disagree would let a request say one author asked for
    # changes the draft says another author is still waiting to apply.
    request = build_request(submitted_by: users(:user_two))

    assert_not request.valid?
    assert_includes request.errors[:submitted_by], I18n.t("review_requests.errors.submitted_by_must_be_author")
  end

  test "a rejection has to say why" do
    # The whole purpose of a rejection is to tell the author why, so notes are how
    # it does that. This is the same argument `Draft`'s `closed_at` makes: a fact
    # that cannot be recovered afterwards is stored now or not at all.
    request = build_request(status: "rejected", reviewed_by: users(:user_two))

    assert_not request.valid?
    assert_includes request.errors[:review_notes], I18n.t("review_requests.errors.notes_required")

    assert build_request(status: "rejected", reviewed_by: users(:user_two), review_notes: "Wrong story").valid?

    # An approval has nothing to explain, which is why the rule is on the
    # rejection rather than on every decision.
    assert build_request(status: "approved", reviewed_by: users(:user_two)).valid?,
      "requiring notes on an approval would make reviewers write filler"
  end

  test "a decision has to say who made it" do
    # A reviewed request with no reviewer is a row that cannot answer "who let
    # this through", which is the one question an audit of this universe has to be
    # able to ask.
    request = build_request(status: "approved")

    assert_not request.valid?
    assert_includes request.errors[:reviewed_by], I18n.t("review_requests.errors.reviewer_required")

    # A pending request is not a failure for having no reviewer — nobody has
    # looked at it yet, which is what `optional: true` is for.
    assert build_request.valid?, "a request nobody has looked at yet has no reviewer, and that is not a fault"
  end

  test "one draft has one review in flight, and a rejected one is history" do
    # The partial index, and the reason it is partial: a rejected submission
    # stays behind as history and the author may submit again, while two *pending*
    # requests for one draft would mean two reviewers racing to apply the same
    # changes.
    first = create_request

    assert_raises ActiveRecord::RecordNotUnique do
      create_request
    end

    first.update!(status: "rejected", reviewed_by: users(:user_two), review_notes: "Not this one")

    second = create_request

    assert_equal [ first, second ], @draft.review_requests.order(:id).to_a
    assert_equal [ second ], ReviewRequest.pending.to_a,
      "a rejected submission is the author's history, not a reviewer's queue entry"
    assert_equal second, @draft.reload.pending_review_request
  end

  test "the unique index covers exactly the pending status" do
    # The migration froze the status in SQL, because a migration has to keep saying
    # what it said on the day it ran, so the duplication is real and this is what
    # holds it. If a status joined `PENDING` without joining the index, two
    # requests that both counted as waiting could exist — the exact pair the index
    # exists to refuse.
    index = ReviewRequest.connection.indexes(:review_requests)
      .find { |candidate| candidate.name == "index_review_requests_on_draft_while_pending" }

    assert index&.unique, "one review in flight per draft is a database rule, not only an application one"
    assert_equal %w[draft_id], index.columns
    assert_equal [ ReviewRequest::PENDING ], index.where.scan(/'([^']+)'/).flatten
  end

  test "a draft submits itself and a review request in one step" do
    request = @draft.submit!

    assert_predicate request, :pending?
    assert_equal @draft, request.draft
    assert_equal @universe, request.universe
    assert_equal @author, request.submitted_by
    # Both halves, or neither: a `submitted` draft with no request is a draft
    # nobody is ever going to look at, and a request against a draft that still
    # says `draft` is a queue entry whose subject the author can still edit under.
    assert_equal "submitted", @draft.reload.status
    assert_predicate @draft, :submitted?
    assert_predicate @draft, :open?, "a submitted draft is waiting for a reviewer, not finished"
    assert_nil @draft.closed_at
  end

  test "only a working draft can be submitted" do
    submitted = @draft.submit!

    assert_raises ActiveRecord::RecordNotSaved do
      @draft.submit!
    end
    assert_equal 1, @draft.review_requests.count,
      "a refused submission leaves the draft's history exactly as it was"
    assert_equal submitted, @draft.reload.pending_review_request

    @draft.update!(status: "applied", closed_at: Time.current)

    assert_raises ActiveRecord::RecordNotSaved do
      @draft.submit!
    end
  end

  test "a submission goes when its draft does, and when its universe does" do
    request = @draft.submit!
    assert_equal request, @draft.pending_review_request

    @draft.destroy

    assert_not ReviewRequest.exists?(request.id),
      "a submission reviews the changes the draft carries and cannot outlive them"

    # And the universe cascade, which reaches the request through the draft for
    # the same reason it reaches the draft itself.
    other = Draft.create!(user: @author, universe: @universe)
    other.submit!

    @universe.destroy

    assert_empty ReviewRequest.where(universe_id: @universe.id)
  end

  test "a draft with no submission says so rather than inventing one" do
    assert_empty @draft.review_requests
    assert_nil @draft.pending_review_request
    assert_not_predicate @draft, :submitted?
  end

  private

    def build_request(status: "pending", universe: @universe, submitted_by: @author, **attributes)
      ReviewRequest.new(draft: @draft, universe: universe, submitted_by: submitted_by,
        status: status, **attributes)
    end

    def create_request(**attributes)
      build_request(**attributes).tap(&:save!)
    end
end
