module Authentication
  extend ActiveSupport::Concern

  included do
    before_action :require_authentication
    helper_method :authenticated?
  end

  class_methods do
    def allow_unauthenticated_access(**options)
      skip_before_action :require_authentication, **options
    end
  end

  private
    def authenticated?
      resume_session
    end

    def require_authentication
      resume_session || request_authentication
    end

    def resume_session
      Current.session ||= find_session_by_cookie
    end

    def find_session_by_cookie
      return unless cookies[:session_id].present?

      Session.find_by(id: cookies.signed[:session_id]) || invalidate_stale_session
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    # Where a successful sign-in sends the visitor: the page that refused them, or
    # the page they opened the form from, or the universe list when there is
    # nothing to return to. A remembered sign-in or password page is never a
    # destination — the request that follows this redirect is also marked, so a
    # page the new session cannot read answers with the universe list instead of
    # a bare 403/404 (see `ApplicationController#refuse_request`).
    def after_authentication_url
      destination = session.delete(:return_to_after_authenticating)
      destination = nil if authentication_page?(destination)

      session[:post_sign_in_destination] = true
      destination || root_url
    end

    # True for a URL that is itself part of signing in, so it cannot be the
    # answer to "where were you?".
    #
    # After a wrong password the browser reopens the form, and the referer it
    # sends with that request is the sign-in endpoint or the sign-in page itself
    # (a plain refresh of the form sends the same self-referer). Either one
    # stored as the destination made a *correct* password land back on the form —
    # or on the POST endpoint, which no GET route answers — looking like nothing
    # had happened even though the session cookie was set. The password pages are
    # refused for the same reason: they ask for something the visitor has just
    # proved they do not need.
    def authentication_page?(url)
      return false if url.blank?

      path = URI.parse(url).path
      return true if [ session_path, new_session_path ].include?(path)

      path.start_with?("#{passwords_path}/")
    rescue URI::InvalidURIError
      # A referer is a client-supplied header, so it is parsed defensively: a
      # malformed one must not turn a correct password into a 500.
      false
    end

    def start_new_session_for(user)
      clear_remembered_stories
      user.sessions.create!(user_agent: request.user_agent, ip_address: request.remote_ip).tap do |session|
        Current.session = session
        cookies.signed.permanent[:session_id] = {
          value: session.id,
          httponly: true,
          same_site: :lax,
          secure: Rails.env.production?
        }
      end
    end

    def terminate_session
      clear_remembered_stories
      Current.session.destroy
      Current.session = nil
      cookies.delete(:session_id)
    end

    def invalidate_stale_session
      clear_remembered_stories
      cookies.delete(:session_id)
      nil
    end

    def clear_remembered_stories
      session.delete(:current_story_ids)
    end
end
