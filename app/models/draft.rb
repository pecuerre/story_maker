# The changes one author has remembered for one universe, not yet applied.
#
# A draft belongs to a person and to a universe, and those are two independent
# halves of the same scope: the universe is what authorizes the change, and the
# author is who may see, apply, or discard it. Neither can be derived from a
# row that is not there yet — a draft whose first change creates a record has no
# record to derive either from — so both are stored, and `DraftChange` checks
# its record against the universe the draft names rather than trusting either
# column.
#
# This is deliberately **not** registered in `Ability::CONTENT_CLASS_NAMES`. A
# pending change is not something a universe publishes, and registering it there
# would let the content rules answer `read` for a guest in a public universe,
# which is precisely the wrong answer for somebody else's unfinished work. The
# content rules are instance blocks over universe-scoped records; a draft is
# read as its owner's, inside the universe the request has already authorized.
#
# There **is** a unique index on `[user_id, universe_id]`, and it is partial: it
# covers `OPEN_STATUSES` and nothing else. An applied or discarded draft stays
# behind as history, so a constraint across *all* statuses would make a second
# editing session impossible (ADR 0019), while no constraint at all let two tabs
# open two drafts that could then both be applied (ADR 0022). One **open** draft
# per author per universe is the rule, so that is what the database says, and
# `open_for!` is what resolves the one race it leaves behind.
#
# **A closed draft says when it was closed, and what its run did.** `closed_at` is
# the moment the draft left `OPEN_STATUSES`, and the three counts beside it are the
# run's tally, stored rather than recomputed so the drafts list can print a
# history without resolving anything. `DraftChangeOutcome` holds the same run one
# change at a time, and `DraftApplier` writes both halves from one `Result` inside
# one transaction; `test/services/draft_applier_test.rb` asserts the columns
# against the rows. The validation below is what keeps "when" from being an
# inference: a draft that cannot be acted on any more and does not say when it
# stopped being actionable is a row whose history would have to guess.
#
# The status vocabulary is owned here and validated against `STATUSES`, the same
# list the column default comes from: a status the application has no behaviour
# for would otherwise be a draft that nothing can apply or discard, and the
# reader would find that out by watching a control do nothing.
class Draft < ApplicationRecord
  STATUSES = %w[draft applied discarded submitted].freeze

  # The statuses a change may still be added to and applied from. It is a list
  # rather than a second `open?` expression because four things read it: the finder
  # below, the pending-count query, the predicate, and the partial unique index that
  # makes "one open draft" something the database says. "Is this draft still open"
  # has to be the same question wherever it is asked, or a second editing session
  # could be opened onto a draft whose changes the apply workflow would not touch.
  OPEN_STATUSES = %w[draft submitted].freeze

  belongs_to :user
  belongs_to :universe

  # The changes read as the order they were written in. Two changes stored inside
  # one clock tick still have an order, so `id` is the tiebreaker.
  has_many :draft_changes, -> { order(:created_at, :id) }, dependent: :destroy

  # What the apply decided about each of those changes. It is a separate table
  # rather than columns on `draft_changes` because a remembered change is
  # append-only (ADR 0019), and it is destroyed with the draft because an outcome
  # is a statement about a run that happened inside this draft.
  has_many :draft_change_outcomes, dependent: :destroy

  # The submissions this draft has been handed over for, oldest first. A rejected
  # one stays behind as history and the author may submit again, so this is the
  # draft's history of asking rather than one row about the draft; destroying the
  # draft takes them, because a submission reviews the changes the draft carries
  # and cannot outlive them.
  has_many :review_requests, dependent: :destroy, inverse_of: :draft

  validates :status, presence: true, inclusion: { in: STATUSES }
  validate :closed_draft_records_when_it_was_closed

  scope :open, -> { where(status: OPEN_STATUSES) }

  # The one draft an author is working in inside one universe, or nil when there is
  # none. There can only be one: the partial unique index refuses a second open
  # draft for the same author and universe, so this is a lookup rather than a
  # search for the most recent of several. History is not in the scope, which is
  # what lets a second editing session have a row of its own.
  def self.open_for(user, universe)
    open.find_by(user: user, universe: universe)
  end

  # `open_for`, opening one when there is none. This is what the interception path
  # and the editing session ask, so "which draft does this change join" and "which
  # draft did this author start editing" have one answer.
  #
  # Two requests that arrive together can both read "no open draft" before either
  # has inserted. The index decides between them, and the loser re-reads the
  # winner's row instead of raising: both requests' changes belong to one author
  # working in one universe, so they belong on one draft that one apply closes.
  # Without this, the second draft would sit there waiting to be applied over
  # whatever the first one left.
  def self.open_for!(user, universe)
    open_for(user, universe) || create!(user: user, universe: universe)
  rescue ActiveRecord::RecordNotUnique
    open_for(user, universe) || raise
  end

  # How many changes this author has waiting in this universe, which is what the
  # universe page states while they are editing. It counts the changes rather than
  # the drafts, and it reads the open scope so an applied or discarded draft's
  # remembered intentions stop counting the moment they stop being pending.
  def self.pending_changes_count(user, universe)
    return 0 if user.nil? || universe.nil?

    DraftChange.where(draft: open.where(user: user, universe: universe)).count
  end

  # Hand this draft over for review instead of applying it, which is what
  # `github` mode does and `wikipedia` does not.
  #
  # The two writes are one operation because one of them without the other is
  # wrong in both directions: a `submitted` draft with no request is a draft
  # nobody is ever going to look at, and a request against a draft that still says
  # `draft` is a reviewer's queue entry whose subject the author can still edit
  # under. So they share a transaction, and a refusal from the request's own
  # validations leaves the draft exactly as it was.
  #
  # Only a working draft can be submitted, and the refusal is a raise rather than
  # a validation error because this is not a form: the caller is a workflow step
  # that already knows the draft's state, and a control that quietly did nothing
  # would leave the author waiting for a reviewer who was never asked.
  def submit!
    raise ActiveRecord::RecordNotSaved, "only a working draft can be submitted: Draft #{id} is #{status}" unless draft?

    transaction do
      request = review_requests.create!(universe: universe, submitted_by: user)

      update!(status: "submitted")

      request
    end
  end

  # The submission this draft is waiting on, or nil when it is not waiting on one.
  # It reads the pending scope rather than the newest request because a draft that
  # was rejected and is being edited again still has the old request behind it,
  # and that one is history rather than the reviewer's queue.
  def pending_review_request
    review_requests.pending.order(:id).last
  end

  # The stored values, asked about by name, so that no caller re-derives a
  # lifecycle state from a raw string. `draft?` is the unfinished state the
  # column defaults to and the one the editing flow creates and resumes; it is
  # named for the stored value rather than for this class, so `draft?` means
  # "still a working draft" and `applied?` means "its changes are live".
  def draft?
    status == "draft"
  end

  def applied?
    status == "applied"
  end

  def discarded?
    status == "discarded"
  end

  def submitted?
    status == "submitted"
  end

  # Whether the draft's changes can still be applied. An applied or discarded
  # draft is history, and re-applying it would write its changes a second time
  # over whatever they were applied to; a submitted one is waiting for a
  # reviewer's decision, which the reviewing workflow owns rather than its
  # author.
  def open?
    OPEN_STATUSES.include?(status)
  end

  # The other half of `open?`, asked about by name because four surfaces ask it:
  # the drafts list, a draft's own page, the applier's precondition, and the
  # sentence the two mutation controls are hidden behind. One question, one
  # answer — `!open?` spelled twice is the kind of duplication that lets a fifth
  # surface decide for itself what history means.
  def closed?
    !open?
  end

  private

    # A draft that can no longer be acted on has to say when it stopped being
    # actionable. Without the moment its history would have to be read off
    # `updated_at`, which is only the same answer by coincidence — it is a
    # timestamp that exists to say a row changed, and the first column to be
    # touched the next time anything writes this draft.
    def closed_draft_records_when_it_was_closed
      return if open? || closed_at.present?

      errors.add(:closed_at, I18n.t("drafts.errors.closed_at_required"))
    end
end
