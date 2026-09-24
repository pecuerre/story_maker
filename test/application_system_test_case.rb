require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  driven_by :selenium, using: :headless_chrome, screen_size: [ 1400, 1400 ] do |options|
    options.binary = ENV["SE_CHROME_PATH"] if ENV["SE_CHROME_PATH"].present?
    # Chrome for Testing on Ubuntu 24.04+ can be blocked by the AppArmor
    # user-namespace policy when it is not launched with the sandbox disabled.
    options.add_argument("--no-sandbox") if ENV["SE_CHROME_NO_SANDBOX"] == "1"
  end

  def after_teardown
    # Keep Chrome profile state (notably password/autofill data) from leaking between tests.
    Capybara.current_session.quit if Capybara::Session.instance_created?
  ensure
    super
  end

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
