require "test_helper"
require "action_cable/connection/test_case"

# A websocket does not re-run the controller's authentication concern, so
# `ApplicationCable::Connection` applies the same session rules itself. These
# cases exist because that copy is the only thing standing between a copied
# cookie and a long-lived connection: nothing else in the request lifecycle
# re-checks it once the handshake has been accepted.
class ApplicationCableConnectionTest < ActionCable::Connection::TestCase
  tests ApplicationCable::Connection

  RECORDED_AGENT = "Mozilla/5.0 (recorded browser)"

  test "a session inside its lifetime and created by this client is accepted" do
    connect_with(session: sessions(:bound), user_agent: RECORDED_AGENT)

    assert_equal users(:user_one), connection.current_user
  end

  # The point of the whole file: the request path would already refuse this
  # cookie, so a websocket that accepted it would make that refusal meaningless.
  test "a session past its deadline is refused" do
    assert_reject_connection do
      connect_with(session: sessions(:expired), user_agent: RECORDED_AGENT)
    end
  end

  test "a session idle past its timeout is refused" do
    assert_reject_connection do
      connect_with(session: sessions(:idle), user_agent: RECORDED_AGENT)
    end
  end

  test "a session presented by a different client is refused" do
    assert_reject_connection do
      connect_with(session: sessions(:bound), user_agent: "Mozilla/5.0 (a different client)")
    end
  end

  test "a cookie naming a session that no longer exists is refused" do
    assert_reject_connection do
      connect_with(session_id: ActiveRecord::FixtureSet.identify(:never_existed),
        user_agent: RECORDED_AGENT)
    end
  end

  test "a connection with no session cookie at all is refused" do
    assert_reject_connection { connect(headers: { "HTTP_USER_AGENT" => RECORDED_AGENT }) }
  end

  private
    # The connection reads the session id from the *signed* cookie jar, so the
    # test puts the id where `sign_in_as` puts it and lets the connection read
    # it back the same way.
    def connect_with(session: nil, session_id: nil, user_agent:)
      cookies.signed[:session_id] = session&.id || session_id
      connect(headers: { "HTTP_USER_AGENT" => user_agent })
    end
end
