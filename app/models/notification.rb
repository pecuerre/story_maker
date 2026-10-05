# One thing that happened to one person, and the two events that write one today.
#
# **A notification is a stored sentence, not a pointer.** Its payload carries the
# universe's slug and name, the draft and submission it is about, the other person's
# name, and a reviewer's note where there is one, so a row renders without
# resolving anything. That is what lets it outlive its subject: a submission is
# destroyed with its draft and with its universe, and a bell entry that raised a 404
# about a universe somebody renamed would be worse than no bell at all. The cost is
# names stored twice — validated by nothing, deliberately — and it is paid in exchange
# for a row that can always be read.
#
# **It is deliberately not registered in `Ability::CONTENT_CLASS_NAMES`**, for the
# reason `Draft` and `ReviewRequest` are not: a notification is a statement about
# somebody's work, and the content rules would answer `read` for a guest in a public
# universe. There is no guest version of this page; the bell is rendered only for a
# signed-in reader and both actions need an account.
#
# **The column is `kind`, not `type`.** `type` is Active Record's single-table
# inheritance discriminator, so a row whose type was `"review_submitted"` would be
# looked up as a class name and raise `SubclassNotFound` on a value this application
# invented. `KINDS` is validated against for the reason `Draft::STATUSES` and
# `ReviewRequest::STATUSES` are: a kind with no sentence behind it would be a badge
# nothing can read.
#
# **`read` is the only column that changes after the row is written**, which is why
# there is no `updated_at`: nothing reports when a reader opened their bell. There is
# no foreign key to the thing being announced, and that is the point above rather than
# an omission.
class Notification < ApplicationRecord
  # The two events and their two answers, rather than one kind per universe or per
  # actor: "a submission is waiting" and "your submission was answered" are the two
  # questions the collaboration workflow leaves a person waiting on, and every surface
  # that shows a notification is showing one of those two answers.
  KINDS = %w[review_submitted review_approved review_rejected].freeze

  # How many the navbar's dropdown prints. The cap is here rather than in the view for
  # `DraftPreview::PANEL_LIMIT`'s reason: the dropdown is rendered on every page of the
  # application, so an unbounded list would print one sentence per notification a reader
  # has ever been sent on every page they open, and the rest belongs on the page the
  # dropdown's last entry links to.
  PANEL_LIMIT = 5

  # Which kind each **decision** is written as. A withdrawal is deliberately absent: it
  # is the author taking back their own work, so there is nobody to tell.
  REVIEW_DECISION_KINDS = {
    "approved" => "review_approved",
    "rejected" => "review_rejected"
  }.freeze

  belongs_to :user

  validates :kind, presence: true, inclusion: { in: KINDS }

  # Newest first, for both surfaces that list them: the reader's own page shows all of
  # them and the navbar shows the first few. `id` breaks a tie the way `draft_changes`
  # does, because two rows written inside one clock tick still have an order and a
  # list that cannot say which came first is not a list.
  scope :newest_first, -> { order(created_at: :desc, id: :desc) }
  scope :unread, -> { where(read: false) }

  # Tell everybody in `recipients` that `kind` happened, with one row each.
  #
  # One row per reader rather than one row with a reader list, because a notification
  # is read by exactly one person: marking it read is that person's act, and a shared
  # row could not say who had seen it.
  #
  # A duplicate is left alone rather than refused. A draft that is rejected and
  # submitted again is two real submissions and two real notices, and the second
  # arrival of the same news is not an error to raise about.
  def self.notify(kind:, recipients:, payload: {})
    Array(recipients).compact.map do |recipient|
      create!(user: recipient, kind: kind, payload: payload)
    end
  end

  # Somebody handed a draft over: the universe's administrators are told, because
  # `admin` access is the whole of who may read the queue, so nobody else has a way of
  # finding out that something is waiting.
  #
  # **The author is not told about their own submission.** They pressed the control
  # that caused it and the page they land on already says it, so a notification would
  # be the same news arriving twice. An author who is also the universe's only
  # administrator therefore gets nothing here, which is correct rather than
  # unfortunate: there is nobody else in this universe who could review the draft, and
  # the rule that an owner may approve their own submission already covers it.
  def self.review_submitted!(request)
    notify(
      kind: "review_submitted",
      recipients: request.universe.administrators.where.not(id: request.submitted_by_id),
      payload: review_payload(request, actor: request.submitted_by)
    )
  end

  # A reviewer ruled on somebody's work: the author is told, and nobody else, because
  # the decision is addressed to them. The `review_notes` travel with it because a
  # rejection's notes exist to tell the author why, and a notification that said only
  # "rejected" would send them back to the drafts page to find out what they are
  # supposed to change.
  def self.review_decided!(request)
    kind = REVIEW_DECISION_KINDS.fetch(request.status) do
      raise ArgumentError, "a decision notification needs an approved or rejected request: ReviewRequest #{request.id} is #{request.status}"
    end

    notify(
      kind: kind,
      recipients: request.submitted_by,
      payload: review_payload(request, actor: request.reviewed_by)
    )
  end

  # The payload both entry points write, from the one row they are both about.
  #
  # **The other person's name is stored rather than their id**, and this is the only
  # value here that could have been a pointer instead. A notification renders whatever
  # it says about somebody's work, so a submission that has since been destroyed with
  # its universe would leave a row that either resolves nothing or raises when it is
  # printed; a name copied at the moment it was announced still reads. It is the same
  # trade the universe's own slug and name make above.
  #
  # **The reviewer's note is `presence`, not itself**, for `review_notes`' reason: a
  # rejection always has one and an approval usually does not, and an empty box stored
  # as a blank string would read back as something a reviewer wrote.
  def self.review_payload(request, actor:)
    {
      universe_slug: request.universe.slug,
      universe_name: request.universe.name,
      draft_id: request.draft_id,
      review_request_id: request.id,
      actor_name: actor&.name,
      review_notes: request.review_notes.presence
    }
  end
  private_class_method :review_payload

  def read?
    read
  end

  def unread?
    !read?
  end

  # One notification is marked read on its own, from its own row in the list, because
  # opening the bell is not a decision about every entry in it: a reader who has read
  # three of five and has not read the other two has not read the other two.
  def mark_read!
    return true if read?

    update!(read: true)
  end
end
