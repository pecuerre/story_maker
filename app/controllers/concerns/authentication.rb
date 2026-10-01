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

    # A session cookie is only honoured while the session it names is still
    # within its lifetime and was created by the client presenting it. A cookie
    # that fails either test is deleted exactly like one whose row is gone, so
    # a copied cookie expires on its own instead of staying usable until its
    # owner signs out. The IP address is deliberately not part of that test; see
    # `Session`.
    def find_session_by_cookie
      return unless cookies[:session_id].present?

      session = Session.find_by(id: cookies.signed[:session_id])
      return invalidate_stale_session unless session
      return invalidate_stale_session(session) unless session.active?
      return invalidate_stale_session(session) unless session.created_by?(request.user_agent)

      session.touch_last_used
      session
    end

    def request_authentication
      session[:return_to_after_authenticating] = request.url
      redirect_to new_session_path
    end

    # Where a successful sign-in sends the visitor: the page that refused them, the
    # page they opened the form from, or — when there is nothing to return to and
    # the reader asked to be brought back to their work — the universe and story
    # this account was last working in. A remembered sign-in or password page is
    # never a destination — the request that follows this redirect is also
    # marked, so a page the new session cannot read answers with the universe
    # list instead of a bare 403/404 (see `ApplicationController#refuse_request`).
    def after_authentication_url
      destination = session.delete(:return_to_after_authenticating)
      destination = nil if authentication_page?(destination)

      session[:post_sign_in_destination] = true
      destination || remembered_start_url || root_url
    end

    # The remembered universe and story, as a URL, or nil when there is nothing
    # to return to.
    #
    # It is nil in every case the reader should be sent to the universe list
    # instead: the preference is off, this account has never had a destination,
    # the remembered one belongs to a different account, or the universe and
    # story it names can no longer be opened by this account.
    # `RememberedDestination.for` resolves live records and checks access, so a
    # stale cookie cannot become a link to a page this reader cannot read.
    #
    # This never substitutes the universe's first story. A story is only a
    # landing page because it was explicitly chosen once; the fallback that
    # would make an arbitrary story current stays out of this path.
    def remembered_start_url
      return unless AppStartPage.remember?(cookies)

      destination = RememberedDestination.for(cookies, user: Current.user)
      return if destination.nil?

      if destination.story
        universe_story_url(universe_slug: destination.universe.slug, id: destination.story)
      else
        universe_url(destination.universe)
      end
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
        # The cookie expires with the session's absolute deadline rather than
        # being permanent. A permanent cookie outlives the row it names by
        # twenty years, so the browser would keep presenting a credential the
        # server has already stopped honouring, and the reader would be told to
        # sign in again for no stated reason.
        cookies.signed[:session_id] = {
          value: session.id,
          expires: session.expires_at,
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

    # A session cookie whose row is gone, whose session has reached one of its
    # limits, or which was created by a different client is not a session. The
    # browser is left without a cookie, so it stops presenting a credential the
    # server will not honour, and the row is removed where there is one: such a
    # session is over, and keeping the row would preserve a record of a
    # credential that has already been refused.
    def invalidate_stale_session(session = nil)
      clear_remembered_stories
      cookies.delete(:session_id)
      session&.destroy
      nil
    end

    def clear_remembered_stories
      session.delete(:current_story_ids)
    end
end
