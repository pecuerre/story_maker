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
  # The three events and their three answers, rather than one kind per universe or per
  # actor: "a submission is waiting", "your submission was answered", and "somebody
  # answered you in a conversation you are part of" are the questions the collaboration
  # workflow leaves a person waiting on, and every surface that shows a notification is
  # showing one of those three answers.
  KINDS = %w[review_submitted review_approved review_rejected discussion_reply].freeze

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

  # Somebody answered in a conversation this person is already part of.
  #
  # **The recipients are the thread's other authors, not the universe's people.** A
  # thread is the one place in this application where two people have chosen to talk
  # to each other about one record, so "who is waiting on an answer here" has exactly
  # one answer: whoever else has spoken in it. A member who has never posted, and the
  # universe's administrators, are not in the conversation and are not told about it —
  # which is why this is the one kind whose recipients are not `Universe#administrators`
  # or another access list.
  #
  # **The author of the reply is excluded**, because they are the one person in the
  # universe for whom this news is not news. Replying to your own thread is answered
  # by silence rather than by a row saying you spoke.
  #
  # **A participant who can no longer read the universe is dropped.** The thread's
  # other authors are read from stored messages, and a membership can be removed after
  # somebody posts: telling a reader that a reply arrived in a universe they can no
  # longer open discloses the fact that they said something, to somebody who may not
  # know they ever did. `readable_by?` is asked per participant rather than in one
  # query because a thread holds a handful of authors and the question is per person.
  #
  # **The record's name travels and its class does not.** The sentence says which
  # conversation this is, because "somebody replied" in a bell a reader opens from
  # another universe is a sentence with nothing in it; the class would add nothing
  # printable. The name is read through `RecordTarget` rather than through the
  # thread's own `record` association, for `Discussion`'s reason: a stored
  # `record_type` is a string that must never be constantized, and a name for a
  # record that no longer resolves is a fallback word rather than an exception.
  def self.discussion_replied!(message)
    discussion = message.discussion
    universe = discussion.universe

    notify(
      kind: "discussion_reply",
      recipients: thread_readers(discussion, except: message.user, universe: universe),
      payload: {
        universe_slug: universe.slug,
        universe_name: universe.name,
        discussion_id: discussion.id,
        record_name: RecordTarget.find(record_type: discussion.record_type, record_id: discussion.record_id)&.name,
        actor_name: message.user&.name
      }
    )
  end

  # Everybody but `except` who has spoken in `discussion` and can still read its
  # universe. The author list is the thread's own messages rather than a column on
  # the thread: a thread has no participants, it has a history, and a person who has
  # posted in it is part of it however many times.
  def self.thread_readers(discussion, except:, universe:)
    author_ids = discussion.messages.where.not(user_id: except&.id).distinct.pluck(:user_id)

    User.where(id: author_ids).select { |participant| universe.readable_by?(participant) }
  end
  private_class_method :thread_readers

  # The payload both review entry points write, from the one row they are both about.
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

  # **A row is announced to its reader the moment it is written**, which is how a
  # notification reaches a browser at all. The bell itself is deliberately
  # uncached because its figure moves when somebody else does something in another
  # browser — see `NotificationsHelper#unread_notification_count` — and a figure
  # nothing can tell the page about is a figure that is only right when the page
  # happens to be rendered. So the write publishes to that reader's own stream and
  # the page re-reads itself through their own session.
  #
  # **It is `after_create_commit`, not a broadcast inside the transaction**, for
  # `LiveUpdates`'s reason: a notice written inside a transaction that later rolls
  # back would refresh its reader onto a bell with a row that is not there. Marking
  # a row read announces nothing, because the reader is already looking at the
  # page they pressed the control on.
  after_create_commit :announce_to_the_reader

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

  private

    # Publish this row to the stream its own reader has subscribed to. It is a
    # refresh and nothing more: the row is not rendered here, because the person
    # receiving it may be reading this application in another language and may no
    # longer be able to open the universe the row is about.
    def announce_to_the_reader
      LiveUpdates.notification_written(self)
    end
end
