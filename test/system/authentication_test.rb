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
    # A guest's account menu is the same dropdown, with Log in inside it.
    click_button "Account"
    assert_selector ".dropdown-menu a", text: "Log in"
  end

  test "a guest who signs in from a universe page returns to that page" do
    user = users(:user_one)
    universe = universes(:universe_one)

    visit universe_url(universe)
    assert_selector "h1", text: universe.name

    click_button "Account"
    within ".dropdown-menu" do
      click_link "Log in"
    end

    assert_current_path new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path universe_url(universe)
    assert_selector "h1", text: universe.name
  end
end
