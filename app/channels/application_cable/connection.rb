module ApplicationCable
  class Connection < ActionCable::Connection::Base
    identified_by :current_user

    def connect
      set_current_user || reject_unauthorized_connection
    end

    private
      # A websocket is a long-lived connection that does not re-run the
      # controller's authentication concern, so it has to apply the same session
      # rules itself: the session must still be within its lifetime and must
      # have been created by the client presenting it. Without this, a websocket
      # opened with a cookie the request path would already have refused would
      # still be accepted, which would make the request-time checks
      # meaningless.
      def set_current_user
        session = find_session
        return unless session&.active? && session.created_by?(request.user_agent)

        self.current_user = session.user
      end

      def find_session
        return if cookies.signed[:session_id].blank?

        Session.find_by(id: cookies.signed[:session_id])
      end
  end
end
