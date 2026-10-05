# What this application says over the websocket, and to whom.
#
# **A live update is a signal, never a page.** Every broadcast here is a Turbo
# Stream `refresh` with one extra attribute, and that is the whole design. The
# alternative — broadcasting the rendered rows, the message, the count — would be
# rendered by `ApplicationController.render` outside any request: with no session,
# no `Current`, no locale of the reader who receives it, and no authorization
# answer for them. In a universe with a Spanish reader and an English one, an
# appended message would arrive in whichever language the sender happened to be
# browsing in, and a rendered list would announce records to a subscriber whose
# access to that universe had already been withdrawn. A refresh sends nothing but
# "look again": the reader's own browser re-requests the page, through their own
# session, in their own language, and the page answers for them. This is the same
# boundary [ADR 0016](../docs/adr/0016-internationalization-and-browser-locale.md)
# draws for the client-side strings — the server resolves it, and here it is the
# reader's own request that resolves it — and the same rule the notification bell
# already follows by storing a sentence rather than a pointer.
#
# **Three streams, because there are three audiences.** A universe stream says
# "the records here changed" to everyone with that universe open, which is what
# an applied draft means: a Character that did not exist a second ago is now
# stored, and every list in the universe is stale until it is re-read. A
# discussion stream says "this thread has another message" to the readers already
# looking at it, and only to them — a thread is a conversation between the people
# who posted in it, not a universe-wide event. A reader stream says "your bell has
# something new" to one person, and it is the delivery for every notification the
# application writes: a submission, a decision, a reply. The review workflow's
# three events are announced **through** `Notification` rather than by three more
# broadcasts here, because `Notification` already owns the question of who is told
# (`conventions.md#notifications`), and a second copy of those recipient rules
# would be free to disagree with the rows.
#
# **The stream name is signed, and that is the authorization.** `turbo_stream_from`
# signs what it renders with `Turbo.signed_stream_verifier`, and
# `Turbo::StreamsChannel` refuses a subscription whose signature does not verify,
# so a reader cannot name a stream their own pages never named. The subscription
# itself is rendered only where the request has already authorized that reader for
# that universe (`layouts/_live_updates`), which is why a guest sees no
# subscription at all: `ApplicationCable::Connection` refuses a websocket with no
# session, so there is nothing a guest could receive even if a page asked for it.
#
# **A broadcast is published after the transaction that caused it commits**, which
# is why it hangs off an `after_commit` on the record rather than off the write
# path. A refresh published inside a transaction invites the reader to re-read a
# universe that has not changed yet, and the rollback case would leave a reader
# looking at a message that does not exist.
#
# **The reader's own browser is not told.** `turbo_stream_refresh_tag` carries
# `request-id`, and Turbo drops a refresh whose request id the page has just made
# itself, so the person who pressed **Apply changes** or **Post message** is not
# refreshed underneath the navigation they are already doing.
#
# The client half is `live_update_controller.js`: it takes the refresh over and
# applies it only when the page holds nothing unsaved, because a refresh throws
# away a half-typed reply, a reviewer's notes, and an open editor alike.
module LiveUpdates
  # The first segment of every stream name, which is what keeps a collaboration
  # stream from ever colliding with another kind of stream in this application.
  NAMESPACE = "collaboration".freeze

  class << self
    # Everyone with this universe open. See the module comment: an applied draft
    # is a change to stored records, and every list of the universe is out of date
    # once it lands.
    def universe_stream(universe)
      return nil if universe.nil?

      [ NAMESPACE, "universe", universe.id ]
    end

    # The readers already looking at one thread.
    def discussion_stream(discussion)
      return nil if discussion.nil?

      [ NAMESPACE, "discussion", discussion.id ]
    end

    # One reader's own bell.
    def reader_stream(user)
      return nil if user.nil?

      [ NAMESPACE, "reader", user.id ]
    end

    # Somebody's remembered changes are live now. Called from `Draft`'s own commit
    # so that it is the *write* that announces itself — the author's apply and a
    # reviewer's approval are the same write, and only the write knows.
    def draft_applied(draft)
      refresh(universe_stream(draft.universe), event: "draft_applied")
    end

    # Somebody answered in a thread.
    def discussion_replied(message)
      refresh(discussion_stream(message.discussion), event: "discussion_replied")
    end

    # Somebody is told something, which is how the review workflow's three events
    # reach a browser: the submission reaches the universe's administrators, each
    # decision reaches the author, and a reply reaches the thread's other authors.
    def notification_written(notification)
      refresh(reader_stream(notification.user), event: "notification_written")
    end

    private
      # The one place anything reaches the websocket. The action is Turbo's own
      # `refresh`; `data-live-update` names the event for the client controller and
      # for anyone reading a broadcast in the log, and is what tells that
      # controller that this stream element is one of ours to decide about.
      def refresh(stream, event:)
        return if stream.blank?

        Turbo::StreamsChannel.broadcast_refresh_to(stream, "data-live-update" => event)
      end
  end
end
