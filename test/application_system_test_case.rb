require "test_helper"

# The browser suite gets its own coverage report and no gate.
#
# It is a smoke suite: it drives a handful of journeys in a real browser, so its
# total (about 70% line on 2026-10-01) is not comparable with the request suite's
# and would fail a threshold sized for the whole suite. It also runs in its own CI
# job and its own process, so sharing the request suite's report directory would
# merge two unrelated runs into one number.
SimpleCov.coverage_dir "tmp/coverage-system"
SimpleCov.coverage(:line) { minimum 0 }
SimpleCov.coverage(:branch) { minimum 0 }

class ApplicationSystemTestCase < ActionDispatch::SystemTestCase
  # A mutation in this application is a fetch followed by a same-URL navigation
  # (ADR 0011), so the first assertion after one waits longer than Capybara's
  # default. This only changes how long a passing refresh may take; a genuinely
  # broken flow still fails.
  REFRESH_WAIT = 10

  # A row's menu takes two clicks — one to open it, one to take an entry out of
  # it — so the interaction that reaches a mutation has two chances to be asked
  # for before the page can answer, rather than one.
  MENU_WAIT = 5

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

  # Whether the page is ready to be clicked, asked of Stimulus itself. Turbo
  # registers through a static import, but Stimulus resolves every controller
  # through a dynamic `import()` in `controllers/index.js`, so the document
  # reaches `readyState === "complete"` — the moment Capybara's `visit` returns —
  # before the last controller has been registered *and connected*. "Registered"
  # and "connected" are two different moments and only the second one means a
  # click will be heard, which is what `getControllerForElementAndIdentifier`
  # answers.
  #
  # A page that names no controller is ready by having nothing to wait for: the
  # bare 403 a non-admin is refused with is rendered without the layout, and a
  # case that visits it is there to read the refusal, not to click anything. The
  # attributes are server-rendered, so their absence is the server's answer and
  # not a sign that the JavaScript has not arrived.
  READY_JS = <<~JS
    (function() {
      var elements = document.querySelectorAll("[data-controller]")
      var app = window.Stimulus
      if (elements.length === 0) return { started: true, waiting: 0, missing: [] }
      if (!app || !window.Turbo) return { started: false, waiting: elements.length, missing: [] }
      var missing = []
      elements.forEach(function(element) {
        ;(element.getAttribute("data-controller") || "").trim().split(/\\s+/).filter(Boolean).forEach(function(name) {
          if (!app.getControllerForElementAndIdentifier(element, name)) missing.push(name)
        })
      })
      return { started: true, waiting: elements.length, missing: missing.filter(function(name, index) {
        return missing.indexOf(name) === index
      }) }
    })()
  JS

  # Every case in this suite visits a page and then interacts with it, and a
  # native click delivered before Stimulus and Turbo have connected is silently
  # dropped on some machines: the click reaches the element and nothing answers
  # it, so the next assertion fails for a reason that has nothing to do with the
  # flow under test. Waiting for the readiness signal above after every
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

    # Polled rather than asserted with a selector, because the answer that makes
    # this useful is the *name* of the controller that never connected: a case
    # that fails here has to say which listener was missing, not only that
    # something was. `<html>` carries no loading class to wait on — the pinned
    # Stimulus never sets one — which is why the signal is read from Stimulus.
    def assert_stimulus_loaded(timeout: 10)
      state = wait_for_ready_state(timeout: timeout)
      assert state["started"],
        "Stimulus and Turbo never started on #{page.current_path}, so no click can reach any of its #{state["waiting"]} controllers"
      assert_empty state["missing"],
        "Stimulus never connected the #{state["missing"].to_sentence} controller on #{page.current_path}, so a click would be dropped"
    end

    def wait_for_ready_state(timeout:)
      deadline = Time.now + timeout
      loop do
        state = page.evaluate_script(READY_JS)
        return state if Time.now > deadline || (state["started"] && state["missing"].empty?)
        sleep 0.05
      end
    end

    # One row's action menu, opened and then used.
    #
    # The menu is a `display: none` `<ul>` that the row's own toggle reveals, so
    # the entry is not on the page to be clicked until the toggle has been
    # clicked *and* Bootstrap has shown it. Both halves are Bootstrap's, which is
    # why the wait is for the menu rather than for the entry: an entry found
    # inside a closed menu is a different page.
    #
    # The toggle is addressed by the dropdown rather than by the wrapper class
    # because two row kinds render the same menu and only one of them calls it
    # `.row-actions`: the flat-list workspaces' shared row actions, and the
    # taxonomy tree's own. `match: :first` is the guard for a row that grows a
    # second dropdown, so the row's menu is still the one that opens.
    #
    # `confirm:` is the sentence the browser asks about: a String is asserted as
    # well as accepted, `true` accepts whatever the row's own copy says, and
    # `nil` is for the entry that asks nothing. A delete is the one that asks.
    def click_row_menu_action(row, name, confirm: nil)
      within row do
        find(".dropdown .dropdown-toggle", match: :first).click
        assert_selector ".dropdown-menu.show", visible: :visible, wait: MENU_WAIT
        within ".dropdown-menu.show" do
          # Matched by Bootstrap's own item class rather than by tag, because a
          # row's menu is not one shape: a workspace editor is a button that
          # answers a `fetch`, and a record whose editor is a page of its own is
          # a link. Both are `.dropdown-item`, and inside the open menu the class
          # is enough to say which entry this is.
          entry = find(".dropdown-item", text: name)
          if confirm == true
            accept_confirm { entry.click }
          elsif confirm
            accept_confirm(confirm) { entry.click }
          else
            entry.click
          end
        end
      end
    end
end
