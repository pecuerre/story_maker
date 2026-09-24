require "application_system_test_case"

class AuthenticationTest < ApplicationSystemTestCase
  test "a user can sign in and sign out" do
    user = users(:user_one)

    sign_in_via_form(user)

    assert_selector "button", text: "Account"
    click_button "Account"
    assert_selector ".navbar-account-label", text: user.email_address
    click_on "Log out"

    assert_current_path new_session_path
    assert_selector "h1", text: "Sign in"
    assert_selector "a", text: "Log in"
  end
end
