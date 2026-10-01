require "test_helper"

# A session's two limits and its source binding are the difference between a
# cookie that expires on its own and one that stays usable until its owner
# happens to sign out. These are model-level statements because the policy lives
# on the model: the controller and the websocket connection both ask the row
# rather than re-implementing the rule.
class SessionTest < ActiveSupport::TestCase
  test "a newly created session starts inside both limits and counts as used immediately" do
    session = user.sessions.create!(user_agent: "Mozilla/5.0 (a new browser)")

    assert session.active?
    assert_not session.idle?
    assert_not session.past_absolute_deadline?
    assert_in_delta Time.current.to_i, session.last_used_at.to_i, 1,
      "a new session is used the moment it is created"
    assert_in_delta Session::ABSOLUTE_TIMEOUT.from_now.to_i, session.expires_at.to_i, 1
  end

  test "a session unused past the idle timeout is refused" do
    session = session_named(:active)

    assert_not session.idle?
    assert session.active?(now: session.last_used_at + Session::IDLE_TIMEOUT - 1.minute)
    assert session.idle?(now: session.last_used_at + Session::IDLE_TIMEOUT + 1.minute)
    assert_not session.active?(now: session.last_used_at + Session::IDLE_TIMEOUT + 1.minute)
  end

  test "a session inside its absolute deadline but unused for too long is refused" do
    session = session_named(:idle)

    assert_not session.past_absolute_deadline?
    assert session.idle?
    assert_not session.active?
  end

  # The idle timeout moves with use and the absolute deadline does not: a session
  # that is used continuously still ends, and neither limit can be pushed back
  # by activity.
  test "continued use defers the idle timeout but never the absolute deadline" do
    session = session_named(:active)

    assert_operator session.expires_at, :>, session.last_used_at + Session::IDLE_TIMEOUT

    session.touch_last_used
    assert_operator session.last_used_at, :>, session.last_used_at - Session::IDLE_TIMEOUT
    # Touching updates only `last_used_at`, so the deadline is untouched by use.
    assert_equal session.created_at + Session::ABSOLUTE_TIMEOUT, session.reload.expires_at
  end

  test "a session past its absolute deadline is refused however recently it was used" do
    session = session_named(:active)

    assert_not session.past_absolute_deadline?
    assert session.past_absolute_deadline?(now: session.expires_at + 1.minute)
    assert_not session.active?(now: session.expires_at + 1.minute),
      "the absolute deadline refuses it even though it was used moments earlier"
  end

  # A row that predates these columns cannot be judged, so it is neither expired
  # nor bound: a schema change must not sign everybody out.
  test "a session with no lifetime recorded is treated as still valid" do
    session = session_named(:without_lifetime)

    assert_nil session.expires_at
    assert_nil session.last_used_at
    assert_not session.past_absolute_deadline?
    assert_not session.idle?
    assert session.active?
  end

  # A row with no recorded user agent cannot be checked at all, so it is left
  # alone rather than being refused for the absence of a value.
  test "a session with no recorded user agent cannot be a mismatch" do
    session = session_named(:without_lifetime)

    assert session.created_by?("Mozilla/5.0 (any client at all)")
    assert session.created_by?(nil)
  end

  test "a session is bound to the user agent that created it" do
    session = session_named(:bound)

    assert session.created_by?("Mozilla/5.0 (recorded browser)")
    assert_not session.created_by?("Mozilla/5.0 (a different client)")
    # A recorded agent compared against a client that now sends none is a
    # mismatch: something that is not that browser is presenting the cookie.
    assert_not session.created_by?(nil)
  end

  # The IP address is recorded for diagnostics but never ends a session: it
  # identifies a network rather than a person, and mobile, VPN, and office/home
  # switching all change it legitimately.
  test "a changed IP address does not refuse the session" do
    session = session_named(:bound)

    session.update!(ip_address: "10.0.0.1")
    assert session.active?
    assert session.created_by?("Mozilla/5.0 (recorded browser)")

    session.update!(ip_address: "203.0.113.9")
    assert session.active?
    assert session.created_by?("Mozilla/5.0 (recorded browser)")
  end

  # Refreshing `last_used_at` on every request would make each page view a write
  # for no benefit, so it is deliberately skipped while the stored value is
  # still fresh enough.
  test "touching last used is skipped while the stored value is still fresh" do
    session = session_named(:active)
    original = session.last_used_at

    session.touch_last_used
    assert_in_delta original.to_i, session.reload.last_used_at.to_i, 1,
      "a fresh value is not rewritten"

    refreshed_at = original + Session::LAST_USED_REFRESH_INTERVAL + 1.minute
    session.touch_last_used(now: refreshed_at)
    assert_equal refreshed_at.to_i, session.reload.last_used_at.to_i
  end

  test "the expired scope selects exactly the sessions past their deadline" do
    assert_includes Session.expired, session_named(:expired)
    assert_not_includes Session.expired, session_named(:active)
    assert_not_includes Session.expired, session_named(:without_lifetime)
  end

  private
    def user
      users(:user_one)
    end

    # A session has no slug, so a fixture declares its id from its label; the
    # same value `sign_in_as` would produce for that label.
    def session_named(name)
      Session.find(ActiveRecord::FixtureSet.identify(name))
    end
end
