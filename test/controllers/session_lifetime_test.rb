require "test_helper"

# The request-level half of session lifetime. The policy lives on the model, so
# these cases are about the wiring: that a request refuses a session the model
# calls inactive, that it refuses one created by a different client, and that a
# refused session is removed rather than merely ignored.
#
# `Current` is reset between requests by the Rails executor, so what a case
# asserts is the response, the cookie the browser was left with, and the row in
# the database — never `Current.session` after the fact.
class SessionLifetimeTest < ActionDispatch::IntegrationTest
  # The client these sessions are created with. A request that presents it is the
  # same browser that signed in; anything else is a different client, which is
  # the case source binding exists to end the session for.
  CLIENT = "Rails Integration Client".freeze
  OTHER_CLIENT = "A Different Browser".freeze

  setup do
    @user = users(:user_one)
  end

  test "a signed-in reader with an active session reaches the universe list" do
    session = active_session
    sign_in_with(session)

    get universes_url, headers: client_headers

    assert_response :success
    assert cookies[:session_id].present?
    assert Session.exists?(session.id)
  end

  test "an idle session is refused and its cookie deleted" do
    session = active_session
    session.update!(last_used_at: Session::IDLE_TIMEOUT.ago - 1.minute)
    sign_in_with(session)

    get universes_url, headers: client_headers

    assert_empty cookies[:session_id].to_s
    assert_not Session.exists?(session.id)
  end

  test "a session past its absolute deadline is refused even when recently used" do
    session = active_session
    session.update!(expires_at: 1.minute.ago, last_used_at: Time.current)
    sign_in_with(session)

    get universes_url, headers: client_headers

    assert_empty cookies[:session_id].to_s
    assert_not Session.exists?(session.id)
  end

  # The IP address identifies a network, not a person, so it is recorded and
  # never enforced: changing it must not sign a legitimate reader out.
  test "a session used from a different IP address is kept" do
    session = active_session
    session.update!(ip_address: "203.0.113.9")
    sign_in_with(session)

    get universes_url, headers: client_headers

    assert_response :success
    assert Session.exists?(session.id)
    assert cookies[:session_id].present?
  end

  test "a session presented by a different client is refused and its cookie deleted" do
    session = active_session
    sign_in_with(session)

    get universes_url, headers: client_headers(client: OTHER_CLIENT)

    assert_empty cookies[:session_id].to_s
    assert_not Session.exists?(session.id)
  end

  # A session created before the user agent was recorded cannot be checked, so
  # the absence of the column must not sign anyone out.
  test "a session with no recorded user agent is accepted from any client" do
    session = active_session
    session.update_column(:user_agent, nil)
    sign_in_with(session)

    get universes_url, headers: client_headers(client: OTHER_CLIENT)

    assert_response :success
    assert Session.exists?(session.id)
  end

  test "a request refreshes a stale last_used_at" do
    session = active_session
    stale = Session::LAST_USED_REFRESH_INTERVAL.ago - 1.minute
    session.update!(last_used_at: stale)
    sign_in_with(session)

    get universes_url, headers: client_headers

    assert_operator session.reload.last_used_at, :>, stale
  end

  test "signing in issues a cookie that expires with the session rather than a permanent one" do
    post session_path, params: { email_address: @user.email_address, password: "password" },
      headers: client_headers

    assert_redirected_to root_path
    assert cookies[:session_id].present?

    set_cookie = Array(response.headers["Set-Cookie"]).join("\n")
    assert_match(/HttpOnly/i, set_cookie)
    assert_match(/SameSite=Lax/i, set_cookie)
    # A permanent cookie carries a far-future date and would outlive the row it
    # names by twenty years, so the browser would keep presenting a credential
    # the server has already stopped honouring.
    assert_no_match(/Expires=.*20[3-9]\d/, set_cookie)

    session = @user.sessions.order(:id).last
    cookie_expiry = set_cookie[/expires=([^;]+)/i, 1]
    assert_equal session.expires_at.httpdate, Time.httpdate(cookie_expiry).httpdate,
      "the cookie expires with the session rather than at some unrelated date"
  end

  # The fixtures include one session that is already past its deadline, so the
  # job's own removal is asserted alongside it rather than in isolation.
  test "the cleanup job removes expired sessions and keeps the rest" do
    already_expired = sessions(:expired)
    assert Session.expired.exists?(already_expired.id)
    kept = active_session

    PurgeExpiredSessionsJob.perform_now

    assert_not Session.exists?(already_expired.id)
    assert Session.exists?(kept.id)
    assert_empty Session.expired
  end

  private
    def active_session
      @user.sessions.create!(user_agent: CLIENT, ip_address: "198.51.100.20")
    end

    def client_headers(client: CLIENT)
      { "HTTP_USER_AGENT" => client }
    end

    # Writes the signed session cookie the application actually reads, without
    # creating a second session the way `sign_in_as` does.
    def sign_in_with(session)
      ActionDispatch::TestRequest.create.cookie_jar.tap do |cookie_jar|
        cookie_jar.signed[:session_id] = session.id
        cookies["session_id"] = cookie_jar[:session_id]
      end
    end
end
