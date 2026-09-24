class PasswordsController < ApplicationController
  allow_unauthenticated_access
  skip_before_action :set_current_universe
  skip_before_action :authorize_universe_access
  before_action :set_user_by_token, only: %i[ edit update ]
  rate_limit to: 10, within: 3.minutes, only: :create, with: -> { redirect_to new_password_path, alert: "Try again later." }

  def new
  end

  def create
    if user = User.find_by(email_address: params[:email_address])
      PasswordsMailer.reset(user).deliver_later
    end

    redirect_to new_session_path, notice: "Password reset instructions sent (if user with that email address exists)."
  end

  def edit
  end

  def update
    if @user.update(params.permit(:password, :password_confirmation))
      reset_sessions_for(@user)
      redirect_to new_session_path, notice: "Password has been reset."
    else
      redirect_to edit_password_path(params[:token]), alert: "Passwords did not match."
    end
  end

  private
    def reset_sessions_for(user)
      current_session_belongs_to_user = Current.session&.user_id == user.id
      user.sessions.destroy_all
      return unless current_session_belongs_to_user

      clear_remembered_stories
      cookies.delete(:session_id)
      Current.session = nil
    end

    def set_user_by_token
      @user = User.find_by_password_reset_token!(params[:token])
    rescue ActiveSupport::MessageVerifier::InvalidSignature
      redirect_to new_password_path, alert: "Password reset link is invalid or has expired."
    end
end
