# One signed-in browser session.
#
# The row records who the session belongs to and which client created it, and it
# now also records when the session ends and when it was last seen. Those two
# timestamps are what make an idle session distinguishable from an active one,
# and they are the reason a copied session cookie stops working on its own
# instead of staying usable until its owner happens to sign out.
#
# The two limits are deliberately different kinds of rule:
#
#   * `IDLE_TIMEOUT` is measured from `last_used_at`, which advances while the
#     session is in use. It is refreshed on a coarse interval rather than on
#     every request, because a timestamp written on every page view would make
#     each request a write for no benefit.
#   * `ABSOLUTE_TIMEOUT` is measured from `created_at` and never moves, so a
#     session that is used continuously still ends.
#
# `SOURCE_MATCHING` records that the session is bound to the user agent it was
# created with. It deliberately does **not** bind to the IP address: an address
# identifies a network, not a person, and mobile connections, VPNs, and
# switching between an office and home network all change it legitimately. A
# copied cookie replayed from a different browser or client presents a
# different user agent, which is the case worth ending the session for. A row
# with no recorded user agent cannot be checked at all and is left alone, so a
# session created before this column existed is never invalidated by its absence.
class Session < ApplicationRecord
  # How long a session may go unused before it stops being accepted. Two weeks
  # is long enough that an author returning to a project is not signed out, and
  # short enough that an abandoned session does not linger.
  IDLE_TIMEOUT = 2.weeks

  # How long a session may exist in total, however often it is used. A year
  # matches the lifetime of the other long-lived browser values in this
  # application, so signing in again yearly is a routine event rather than a
  # surprise.
  ABSOLUTE_TIMEOUT = 1.year

  # How stale `last_used_at` may be before a request refreshes it. A session in
  # active use is therefore touched at most this often, and the idle window is
  # only ever short by this much.
  LAST_USED_REFRESH_INTERVAL = 1.hour

  belongs_to :user

  before_validation :apply_lifetime, on: :create

  # Sessions past their absolute deadline. Used by the cleanup task, so it is
  # the same question the per-request check asks.
  scope :expired, -> { where(expires_at: ..Time.current) }

  # Whether this session may still be used, judged against the two limits.
  # The `now` argument exists so a test can state a deadline instead of
  # travelling through it.
  def active?(now: Time.current)
    !past_absolute_deadline?(now: now) && !idle?(now: now)
  end

  # Past the deadline that no amount of use can move. A row with no
  # `expires_at` predates this column and is treated as still valid, so an
  # existing session is signed out by its owner's next action rather than by a
  # schema change.
  def past_absolute_deadline?(now: Time.current)
    expires_at.present? && expires_at <= now
  end

  # Unused for longer than `IDLE_TIMEOUT`. A row with no `last_used_at`
  # predates this column and is measured from when it was created, which is the
  # only honest answer available for it.
  def idle?(now: Time.current)
    last_activity = last_used_at || created_at
    last_activity.present? && last_activity <= now - IDLE_TIMEOUT
  end

  # Whether this session was created by the client presenting it now.
  #
  # Only a *recorded* user agent is compared. An unrecorded one means the
  # session was created somewhere that did not capture it, and refusing to
  # match a missing value against a present one would end sessions for a reason
  # that has nothing to do with this client.
  def created_by?(user_agent)
    return true if self[:user_agent].blank?

    self[:user_agent] == user_agent.to_s
  end

  # Record that this session just carried a request. Skipped while the stored
  # value is fresh enough, so an actively used session is not written on every
  # request.
  def touch_last_used(now: Time.current)
    return if last_used_at.present? && last_used_at > now - LAST_USED_REFRESH_INTERVAL

    update_column(:last_used_at, now)
  end

  private
    # A new session starts at the full absolute lifetime and counts as used
    # immediately, so it is not idle in the moment it is created. `created_at`
    # is not read here: Rails assigns the timestamp after validation, so it is
    # still nil, and the two values are derived from the same clock reading
    # instead so they can never disagree by a fraction.
    def apply_lifetime
      now = Time.current
      self.expires_at ||= now + ABSOLUTE_TIMEOUT
      self.last_used_at ||= now
    end
end
