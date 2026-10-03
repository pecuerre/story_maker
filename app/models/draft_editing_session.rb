# Whether this reader is editing this universe **right now**: the browser-side
# claim behind the **Start editing** / **Stop editing** control on the universe
# page.
#
# It is a session value, not a record, for the same reason the remembered story
# map is: it answers "is this browser in the middle of an editing session?", which
# is true of one visit and false of the next. A row would answer a different
# question — "has this author ever edited?" — which the open draft itself answers,
# and which would make a mode that ends at a sign-out look permanent.
#
# **It is stored per universe**, in one hash keyed the way `current_story_ids` is,
# because a visit can span two universes and the second one must not inherit the
# first one's editing session.
#
# **It is not a gate on remembering a change.** In a draft-based universe every
# mutation is remembered whether this flag is set or not (ADR 0020), and the flag
# must never become the switch that decides it: a reader who forgot to press
# **Start editing** would then write straight through, which is the one outcome a
# `wikipedia` universe exists to prevent. What the flag owns is the *shape* of the
# editing session — that entering one opens the draft before the first change is
# made, and that the universe page can say how much is waiting (ADR 0022).
class DraftEditingSession
  # One key holds every universe the reader is editing in, so a session boundary
  # that clears the flag is a single `delete` rather than a walk over a list.
  KEY = :draft_editing_universe_ids

  class << self
    # Is this reader editing this universe in this session?
    #
    # A signed-in reader is required because a draft belongs to a person, and a
    # guest is sent to sign in before any action runs, so the flag is never read
    # on their behalf. The stored value is `true` rather than a moment: nothing
    # needs to know when the session started, and a truthy check keeps a tampered
    # session from turning into a date the rest of the application would read.
    def active?(session:, user:, universe:)
      return false if user.nil? || universe.nil?

      editing_universe_ids(session)[universe.id.to_s] == true
    end

    # Begin editing: claim the session, and make sure there is a draft to remember
    # changes into.
    #
    # The draft is opened *before* the flag is written, because a reader whose
    # draft cannot be opened has not started editing — and because
    # `Draft.open_for!` resumes an existing draft rather than replacing it, so a
    # second visit to **Start editing** cannot strand the changes already waiting
    # in one. Returns the draft the reader is now editing.
    def start!(session:, user:, universe:)
      draft = Draft.open_for!(user, universe)

      session[KEY] = editing_universe_ids(session).merge(universe.id.to_s => true)
      draft
    end

    # Stop editing: release the claim, and **keep the draft**.
    #
    # Stopping is not discarding. A remembered change is append-only and the draft
    # is where it lives, so throwing the draft away here would delete work the
    # reader can still see, review, and apply. What changes is the session's
    # answer to "am I editing?", and the caller states the count that is still
    # waiting so the release is not read as a loss.
    def stop!(session:, universe:)
      return if universe.nil?

      remaining = editing_universe_ids(session).except(universe.id.to_s)
      remaining.present? ? session[KEY] = remaining : session.delete(KEY)
    end

    private
      # The stored map, read defensively. A session value is the browser's to
      # replay, so a key that is not a hash is no claim at all rather than an
      # exception on every page of a draft-based universe.
      def editing_universe_ids(session)
        stored = session[KEY]
        stored.is_a?(Hash) ? stored : {}
      end
  end
end
