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

  # The reported bug, in the browser. A wrong password sends the visitor back to
  # this same form, and the browser then offers the form (or the sign-in endpoint)
  # as the referer of that reload. Remembering it made the next *correct* password
  # redirect straight back here: the sign-in looked like it had done nothing, and
  # only navigating away to a universe proved otherwise.
  #
  # The email address is retyped because the refusal deliberately does not echo it
  # back: reflecting it would put the address in the URL, the browser history, and
  # the server's request log.
  test "a mistyped password followed by the right one lands on the universe list" do
    user = users(:user_one)

    visit new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "not-the-password"
    click_button "Sign in"

    assert_current_path new_session_path
    assert_selector ".flash-toast", text: "Try another email address or password."

    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path root_path
    assert_selector "h1", text: "Universes"
  end

  test "signing in from a password reset page lands on the universe list" do
    user = users(:user_one)

    visit new_password_path
    click_link "Back to sign in"

    assert_current_path new_session_path
    fill_in "Email address", with: user.email_address
    fill_in "Password", with: "password"
    click_button "Sign in"

    assert_current_path root_path
    assert_selector "h1", text: "Universes"
  end
end
