# The navbar bell's three questions, and the two sentences the bell and the page
# share.
#
# **How many are unread, and what are the newest few.** The count is asked of
# `Current.user` and memoized for the length of the render, like
# `pending_review_request_count` next to it. It is **deliberately uncached**, for that
# helper's reason with one difference: that figure moves because *this* request just
# decided a submission, and a notification's moves because somebody else did
# something in another browser. Nothing here can expire on that write, so a
# `MenuCountCache` entry would promise a stale bell for up to an hour — and a bell is
# the one control whose whole job is to say something new has arrived. It is one
# `COUNT` over the `[user_id, read]` index, asked only for a signed-in reader.
#
# **A notification is a stored sentence**, so the bell does not resolve anything to
# print one: it interpolates the payload and links at the ids inside it. A universe
# whose slug has since changed makes that link a 404, which is the deliberate price of
# a row that still renders when the submission it names has been destroyed with its
# draft — see `Notification`.
module NotificationsHelper
  # How many notifications this reader has not read, which is the badge on the bell.
  def unread_notification_count
    return @unread_notification_count if defined?(@unread_notification_count)

    @unread_notification_count = Current.user ? Current.user.notifications.unread.count : 0
  end

  # The newest few, for the dropdown. Capped at `Notification::PANEL_LIMIT` because
  # the dropdown opens inside the navbar, which is on every page of the application —
  # an unbounded list would print one sentence per notification a reader has ever been
  # sent on every page they open. The rest is on the page the dropdown's last entry
  # links to, which is where the count and the whole list live.
  def recent_notifications
    return @recent_notifications if defined?(@recent_notifications)
    return @recent_notifications = [] if Current.user.nil?

    @recent_notifications = Current.user.notifications.newest_first.limit(Notification::PANEL_LIMIT)
  end

  # Whether the bell has anything at all to say, which is not the same question as
  # whether it has anything unread: a reader who has read everything still has a list,
  # and hiding the bell would hide the way into it.
  def any_notifications?
    return @any_notifications if defined?(@any_notifications)

    @any_notifications = Current.user.present? && Current.user.notifications.exists?
  end

  # What one notification says, as one plain sentence. It is not an `_html` key: the
  # two values interpolated into it come out of a payload rather than out of a model,
  # and the page's own `<time>` element carries the moment beside it rather than
  # inside the sentence.
  def notification_sentence(notification)
    actor = notification.payload&.dig("actor_name")
    universe = notification.payload&.dig("universe_name")
    record = notification.payload&.dig("record_name")

    t("notifications.sentences.#{notification.kind}",
      actor: actor || t("notifications.someone"),
      reviewer: actor || t("notifications.someone"),
      record: record || t("notifications.a_record"),
      universe: universe || t("notifications.a_universe"))
  end

  # Where one notification's row leads, which depends on who it was written to, or nil
  # when there is nothing to link at.
  #
  # A **submission** notice goes to the universe's administrators, so it opens the
  # reviewer's page — the queue entry the approval and rejection controls are on. A
  # **decision** notice goes to the author, so it opens the author's own draft page,
  # which carries the submission's status and the reviewer's notes
  # (`drafts/_submission_status`); the reviewer's page would answer `404`, because a
  # notification is not an authorization and this reader has no admin access. A
  # **reply** notice goes to somebody who was already in the conversation, so it opens
  # the thread itself, inside the universe it is in.
  #
  # **A reply is the one kind whose target is universe-scoped rather than a page of
  # this application's own.** `DiscussionsController#show` resolves the thread through
  # `Current.universe`, so its path carries the universe's slug — the same slug the
  # payload stores, and the reason this notice can still be followed by somebody
  # standing in a different universe. It is also the one target whose reader may open
  # it: `show` is guest-readable, so a recipient who is a plain member, a read-only
  # member, or the universe's owner all land on the thread rather than on a refusal.
  #
  # **A row with nothing to link at renders its sentence and no link.** The payload
  # column is nullable and every row this application writes fills it, so this answers
  # a row that something else wrote — and it answers it rather than raising, because
  # one unreadable row must not take the bell's whole page down with it. That is the
  # same reason the payload is copied rather than joined: reading what a notice *says*
  # never requires the thing it is about still existing.
  def notification_target(notification)
    slug = notification.payload&.dig("universe_slug")

    if notification.kind == "review_submitted"
      return target_for(slug, notification.payload&.dig("review_request_id")) do |id|
        universe_review_request_path(universe_slug: slug, id: id)
      end
    end

    if notification.kind == "discussion_reply"
      return target_for(slug, notification.payload&.dig("discussion_id")) do |id|
        universe_discussion_path(universe_slug: slug, id: id)
      end
    end

    target_for(slug, notification.payload&.dig("draft_id")) do |id|
      universe_draft_path(universe_slug: slug, id: id)
    end
  end

  # A link only when both halves of the address are there. The three kinds name a
  # different id in the payload, so each asks for its own and this holds the rule that
  # a half-filled payload is no link rather than a link to `/u//discussions/`.
  def target_for(slug, id)
    return nil if slug.blank? || id.blank?

    yield(id)
  end

  # A reviewer's note, as its own element rather than as a clause of the sentence, for
  # the same reason the moment is: it is somebody else's words, and a sentence frame
  # around free text has to guess where to put the punctuation.
  def notification_notes(notification)
    notes = notification.payload&.dig("review_notes")

    notes.present? ? t("notifications.notes", notes: notes) : nil
  end
end
