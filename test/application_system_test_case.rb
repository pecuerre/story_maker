require "test_helper"

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # A mutation in this application is a fetch followed by a same-URL navigation
  # (ADR 0011), so the first assertion after one waits longer than Capybara's
  # default. This only changes how long a passing refresh may take; a genuinely
  # broken flow still fails.
  REFRESH_WAIT = 10

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

  # Every case in this suite visits a page and then interacts with it, and a
  # native click delivered before Stimulus and Turbo have connected is silently
  # dropped on some machines: the click never reaches the page at all, so the
  # next assertion fails for a reason that has nothing to do with the flow under
  # test. Waiting for the readiness signal `stimulus-loading` exposes after every
  # navigation makes the whole suite independent of that race, instead of each
  # case having to remember the wait.
  def visit(path, **options)
    super
    assert_stimulus_loaded
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

    # `stimulus-loading` sits on <html> from the first inline script until
    # Stimulus has registered its controllers and connected the page, and
    # Stimulus removes it only then. Waiting for that class to disappear is the
    # supported readiness signal, so a click cannot be delivered to a page whose
    # controllers are not listening yet and turn a slow machine into a flake.
    def assert_stimulus_loaded(timeout: 10)
      assert_selector "html:not(.stimulus-loading)", visible: :all, wait: timeout
    end
end
