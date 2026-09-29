class SessionsController < ApplicationController
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_session_path, alert: "Try again later." }
  skip_before_action :set_current_universe
  skip_before_action :authorize_universe_access
  allow_unauthenticated_access only: %i[ new create ]

  def new
    store_return_path
  end

  def create
    if user = User.authenticate_by(params.permit(:email_address, :password))
      start_new_session_for user
      redirect_to after_authentication_url
    else
      redirect_to new_session_path, alert: "Try another email address or password."
    end
  end

  def destroy
    terminate_session
    redirect_to new_session_path, status: :see_other
  end

  private
    # A reader who opens the sign-in page directly (rather than being redirected
    # from a page that required a session) has nowhere to return to yet, so the
    # page they came from is remembered the same way `request_authentication`
    # remembers the page that refused them. Only a same-host referer is stored,
    # so an external site cannot choose the post-login destination, and a sign-in
    # or password page is never stored: after a wrong password the browser
    # reopens this form with this form as its referer, which would make a
    # *correct* password land back on the form looking like nothing had happened.
    def store_return_path
      return if session[:return_to_after_authenticating].present?

      referer = request.referer
      return if referer.blank? || !referer.start_with?("#{request.base_url}/")
      return if authentication_page?(referer)

      session[:return_to_after_authenticating] = referer
    end
end
