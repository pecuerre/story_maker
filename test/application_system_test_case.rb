require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ]

  private
    def sign_in_via_form(user, password: "password")
      visit new_session_path
      assert_selector "h1", text: "Sign in"
      fill_in "Email address", with: user.email_address
      fill_in "Password", with: password
      assert_field "Email address", with: user.email_address
      assert_field "Password", with: password
      click_button "Sign in"
      assert_current_path root_path
      assert_selector "button", text: "Account"
    end
end
