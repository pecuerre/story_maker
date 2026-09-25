require "test_helper"

class PasswordsControllerTest < ActionDispatch::IntegrationTest
  setup { @user = User.take }

  test "new" do
    get new_password_path
    assert_response :success
  end

  test "create" do
    post passwords_path, params: { email_address: @user.email_address }
    assert_enqueued_email_with PasswordsMailer, :reset, args: [ @user ]
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "create for an unknown user redirects but sends no mail" do
    post passwords_path, params: { email_address: "missing-user@example.com" }
    assert_enqueued_emails 0
    assert_redirected_to new_session_path

    follow_redirect!
    assert_notice "reset instructions sent"
  end

  test "password routes ignore an arbitrary universe scope" do
    get new_password_path(universe_slug: universes(:universe_one).slug)

    assert_response :success
  end

  test "edit" do
    get edit_password_path(@user.password_reset_token)
    assert_response :success
  end

  test "edit with invalid password reset token" do
    get edit_password_path("invalid token")
    assert_redirected_to new_password_path

    follow_redirect!
    assert_notice "reset link is invalid"
  end

  test "password reset pages are not cached and do not send referrers" do
    get edit_password_path(@user.password_reset_token)

    assert_response :success
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "no-referrer", response.headers["Referrer-Policy"]
  end

  test "blank password does not report a successful reset" do
    original_digest = @user.password_digest
    token = @user.password_reset_token

    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "", password_confirmation: "" }
    end

    assert_response :bad_request
    assert_equal original_digest, @user.reload.password_digest
  end

  test "update" do
    assert_changes -> { @user.reload.password_digest } do
      put password_path(@user.password_reset_token), params: { password: "new", password_confirmation: "new" }
      assert_redirected_to new_session_path
    end

    follow_redirect!
    assert_notice "Password has been reset"
  end

  test "update with non matching passwords" do
    token = @user.password_reset_token
    assert_no_changes -> { @user.reload.password_digest } do
      put password_path(token), params: { password: "no", password_confirmation: "match" }
      assert_redirected_to edit_password_path(token)
    end

    follow_redirect!
    assert_notice "Passwords did not match"
  end

  test "successful reset clears the current user's authentication and story context" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    sign_in_as(@user)
    get universe_story_url(universe_slug: universe.slug, id: story)

    put password_path(@user.password_reset_token),
      params: { password: "new", password_confirmation: "new" }

    assert_redirected_to new_session_path
    assert_empty cookies[:session_id]
    assert_nil session[:current_story_ids]
    assert_not @user.sessions.exists?

    get universe_url(universe)
    assert_response :success
    assert_select "span.navbar-context", text: "Select"
  end

  private
    def assert_notice(text)
      assert_select "div", /#{text}/
    end
end
