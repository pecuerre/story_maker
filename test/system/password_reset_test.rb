require "application_system_test_case"

# Browser coverage for the password-reset journey. The controller tests already
# cover the requests; what only a browser can show is the whole path an author
# walks: ask for instructions, follow the link, save a new password, and sign in
# with it. The mail itself is not opened — the token is taken from the record the
# same way the controller does, and the mailer is covered by its own test.
class PasswordResetTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
  end

  test "an author can reset a password and sign in with the new one" do
    visit new_password_path
    assert_selector "h1", text: "Forgot your password?"

    fill_in "Email address", with: @user.email_address
    click_button "Email reset instructions"

    # The response is the same for a known and an unknown address, so it cannot be
    # used to discover whether an account exists.
    assert_current_path new_session_path
    assert_selector ".flash-stack", text: "Password reset instructions sent"

    visit edit_password_path(@user.password_reset_token)
    assert_selector "h1", text: "Update your password"

    fill_in "New password", with: "a-brand-new-password"
    fill_in "Confirm new password", with: "a-brand-new-password"
    click_button "Save password"

    assert_current_path new_session_path
    assert_selector ".flash-stack", text: "Password has been reset."

    fill_in "Email address", with: @user.email_address
    fill_in "Password", with: "a-brand-new-password"
    click_button "Sign in"

    assert_current_path root_path
    assert_selector "button", text: "Account"
    assert @user.reload.authenticate("a-brand-new-password")
    assert_not @user.reload.authenticate("password")
  end

  test "a mismatched confirmation is refused and keeps the author on the form" do
    visit new_password_path
    visit edit_password_path(@user.password_reset_token)

    fill_in "New password", with: "a-brand-new-password"
    fill_in "Confirm new password", with: "something-else"
    click_button "Save password"

    assert_selector ".flash-stack", text: "Passwords did not match"
    assert @user.reload.authenticate("password"), "the stored password must be unchanged"
  end

  test "an invalid token returns to the request form with an explanation" do
    visit edit_password_path("not-a-real-token")

    assert_current_path new_password_path
    assert_selector ".flash-stack", text: "Password reset link is invalid or has expired"
  end
end
