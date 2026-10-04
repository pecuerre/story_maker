# One author's request that somebody else apply a draft.
#
# This is the row a `github` universe hands over instead of applying: the author
# remembers changes, submits them, and a reviewer approves or rejects. Nothing
# about it is universe content — it is somebody's unfinished work under somebody
# else's decision — so it is deliberately **not** registered in
# `Ability::CONTENT_CLASS_NAMES`, exactly like `Draft`. The reviewer's list is a
# query inside a universe the request has already authorized at the admin level,
# and registering this would let the content rules answer `read` for a guest in a
# public universe, which is the wrong answer for the same reason it is for a
# draft.
#
# **A new row per submission, not columns on `drafts`.** A rejected draft comes
# back as a working draft and can be submitted again, so "which review is this
# draft waiting for" is a history of submissions rather than one fact about the
# draft. The statuses answer what happened to each of them, and the partial
# unique index on `draft_id` over `pending` is the rule that only one of them can
# be waiting at a time.
#
# **`universe_id` and `submitted_by_id` are both derivable from the draft** — the
# universe the draft was authorized in, and its one author — and both are stored
# anyway, because they are what a reviewer's list is queried by without a join.
# A derivable column that is also stored is a column that can disagree with the
# one it came from, so both are validated against the draft rather than trusted,
# which is `DraftChangeOutcome`'s arrangement and `Discussion`'s.
#
# `reviewed_by` is optional because nobody has reviewed a pending request yet.
# `review_notes` is optional because an approval has nothing to explain, and
# **required** for a rejection, whose only purpose is to say why.
class ReviewRequest < ApplicationRecord
  STATUSES = %w[pending approved rejected].freeze

  # The one status a reviewer has not yet answered. It is named rather than
  # repeated as a literal at the two places that ask it, so the scope, the
  # predicate, and the partial index all name one value — and the test that holds
  # the index's frozen SQL against it is the reason that is worth a constant.
  PENDING = "pending"

  belongs_to :draft
  belongs_to :universe
  belongs_to :submitted_by, class_name: "User"
  belongs_to :reviewed_by, class_name: "User", optional: true

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :belongs_to_the_same_universe_as_its_draft
  validate :submitted_by_is_the_drafts_author
  validate :rejection_explains_itself
  validate :reviewed_by_matches_a_decision

  scope :pending, -> { where(status: PENDING) }

  # The stored values, asked about by name, so no caller re-derives a review state
  # from a raw string — the same reason `Draft` names its four statuses.
  def pending?
    status == PENDING
  end

  def approved?
    status == "approved"
  end

  def rejected?
    status == "rejected"
  end

  # Whether a reviewer has answered. The other half of `pending?`, asked about by
  # name because a reviewer's list and an author's own view both need it, and
  # `!pending?` spelled twice is the kind of duplication that lets a fifth surface
  # decide for itself what "still waiting" means.
  def decided?
    !pending?
  end

  # The reviewer's other answer: this submission is refused and the draft comes
  # back to its author as working work.
  #
  # **The two writes are one transaction for `submit!`'s reason read backwards.** A
  # rejected request whose draft still says `submitted` is a request the queue has
  # answered and a draft nobody can edit, and a draft back in the author's hands
  # while the queue still lists it as pending is the opposite failure. So either
  # both move or neither does, and a refusal from this row's own validations — the
  # notes a rejection must carry — leaves the draft exactly as it was.
  #
  # The draft goes back to `draft` rather than being closed: a rejection is not the
  # author's decision about their own work, it is somebody else's, and the changes
  # are still theirs to edit and submit again. That is also why this method returns
  # whether it wrote rather than raising: a rejection with no notes is an answer the
  # reviewer can still give, so it is a form error beside the field and not a crash.
  #
  # **A refused rejection leaves the stored row saying `pending`, and the instance says
  # so too.** The caller renders the submission the queue is looking at, with these
  # errors beside the field; an instance left holding `status = "rejected"` it never
  # saved would hide the controls that produce the answer, because a page that has
  # decided the review would have nothing left to offer.
  #
  # **Approving is deliberately not here.** An approval is an apply — `DraftApplier`
  # writing every remembered change — and its decision must land in the same
  # transaction as the run, which is a service's transaction to own. The asymmetry is
  # the honest shape of the two actions rather than an oversight.
  def reject!(reviewer, notes:)
    assign_attributes(status: "rejected", reviewed_by: reviewer, review_notes: notes)

    unless valid?
      restore_attributes
      return false
    end

    transaction do
      save!
      draft.update!(status: "draft")
    end

    true
  end

  private

    # A stored column that disagrees with the draft is refused rather than
    # resolved, as a thread's is. A submission filed under a universe its draft
    # is not in would be reviewed through a scope nobody authorized it against.
    def belongs_to_the_same_universe_as_its_draft
      return if draft.nil? || universe.nil? || draft.universe_id == universe_id

      errors.add(:universe, I18n.t("shared.errors.same_scope.universe"))
    end

    # A draft has exactly one author, so the person who submits it is the draft's
    # author. Letting the two disagree would let a review request say one author
    # asked for changes the draft says another author is waiting to apply.
    def submitted_by_is_the_drafts_author
      return if draft.nil? || submitted_by.nil? || draft.user_id == submitted_by_id

      errors.add(:submitted_by, I18n.t("review_requests.errors.submitted_by_must_be_author"))
    end

    # A rejection exists to tell the author why. Notes are how it does that, so a
    # rejection without them is a decision the author can only discover happened,
    # which is the failure `Draft`'s `closed_at` validation refuses in the same
    # shape: a fact that cannot be recovered afterwards is stored now or not at all.
    def rejection_explains_itself
      return unless rejected?
      return if review_notes.present?

      errors.add(:review_notes, I18n.t("review_requests.errors.notes_required"))
    end

    # A decision says who made it. A reviewed request with no reviewer is a row
    # that cannot answer "who let this through", which is the one question an
    # audit of this universe has to be able to ask. A pending request has no
    # reviewer yet, which is what `optional: true` above is for.
    def reviewed_by_matches_a_decision
      return if pending?
      return if reviewed_by.present?

      errors.add(:reviewed_by, I18n.t("review_requests.errors.reviewer_required"))
    end
end
