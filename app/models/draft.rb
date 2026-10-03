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
# There is no unique index on `[user_id, universe_id]`, and that is a decision
# rather than an omission: the collaboration plan keeps one draft at a time per
# author per universe, but an applied draft stays behind as history, so a
# constraint across *all* statuses would make a second editing session
# impossible. "One open draft" is a rule of the editing flow that asks this
# model, not of the schema.
#
# The status vocabulary is owned here and validated against `STATUSES`, the same
# list the column default comes from: a status the application has no behaviour
# for would otherwise be a draft that nothing can apply or discard, and the
# reader would find that out by watching a control do nothing.
class Draft < ApplicationRecord
  STATUSES = %w[draft applied discarded submitted].freeze

  belongs_to :user
  belongs_to :universe

  # The changes read as the order they were written in. Two changes stored inside
  # one clock tick still have an order, so `id` is the tiebreaker.
  has_many :draft_changes, -> { order(:created_at, :id) }, dependent: :destroy

  validates :status, presence: true, inclusion: { in: STATUSES }

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
    draft? || submitted?
  end
end
