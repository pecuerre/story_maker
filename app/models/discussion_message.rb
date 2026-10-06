# One message in one conversation.
#
# The author is stored rather than inferred, and `body` is plain text: the
# collaboration plan defers markdown in discussions, so there is no rendered form
# to keep safe here yet. A future formatting slice changes this model and nothing
# else, because the thread already knows which record it belongs to.
#
# Whether the author may write at all is not decided here. It is an authorization
# question about the thread's record, asked by the controller through `Ability`;
# a model cannot know who is signed in.
class DiscussionMessage < ApplicationRecord
  belongs_to :discussion
  belongs_to :user

  validates :body, presence: true

  # Post a reply and tell the conversation it was posted in, in one transaction.
  #
  # **It answers `true`/`false` rather than raising**, because an empty composer is
  # an ordinary form error here and not a crash: the thread re-renders with the
  # reason beside the field, which is the rule every other form in this application
  # follows. `Draft#submit!` may raise for a far narrower reason — a draft's status
  # transition has no form to report through — and this has one.
  #
  # **The notice is inside the transaction**, for `Draft#submit!`'s reason: a message
  # that landed while its notice failed to write leaves the people it was written to
  # looking at a conversation that did not answer them. Neither row is meaningful
  # without the other.
  #
  # **A message with no author names nobody**, which is the case where the notification
  # writer has nothing to interpolate: `Notification.discussion_replied!` stores the
  # actor's name and the bell falls back to `notifications.someone` when it is
  # missing, so a reply from an account without a name is announced rather than
  # refused. `User` validates `name`'s presence, so an account without one arrives
  # from a direct write or an import rather than from an ordinary create.
  def post!
    posted = false

    transaction do
      posted = save
      raise ActiveRecord::Rollback unless posted

      Notification.discussion_replied!(self)
    end

    posted
  end

  # **A message that landed tells the thread's readers, and only after it has.**
  #
  # The stream is the thread's own rather than the universe's: a reply is a
  # conversation between the people who posted in it, and the readers already
  # looking at it are the only ones whose page has anything to say about it.
  #
  # `after_create_commit` rather than a broadcast inside `post!`, because `post!`
  # answers `false` for an empty composer and rolls its transaction back: a thread
  # refreshed onto a message that was refused is worse than a thread that did not
  # move.
  after_create_commit :announce_to_the_thread

  private

    # See `LiveUpdates` for why this is a refresh rather than the rendered message.
    def announce_to_the_thread
      LiveUpdates.discussion_replied(self)
    end
end
