require "application_system_test_case"

# The Start page preference in a real browser.
#
# `test/controllers/settings_start_page_test.rb` owns the stored value and the
# section's own save/refusal rules, and `test/controllers/remembered_start_test.rb`
# owns the redirect policy — including the case where a page to return to beats
# the remembered story. What only a browser shows here is the two things those
# cannot: that the new section renders beside the other two and its option card
# is submitted by the real button, and that the whole sign-in → story → sign-in
# journey works with real cookies and a real form.
#
# The sign-out is driven through the account menu's form rather than by a
# synthetic click on it: that control is a `button_to` inside a Bootstrap dropdown
# in a `position: fixed-top` navbar, where Capybara scrolls the element into view
# and the fixed navbar does not move with the document, so the click lands
# somewhere else. The form itself is correct and does submit. Sign-out is covered
# by `test/controllers/sessions_controller_test.rb`.
class SettingsStartPageTest < ApplicationSystemTestCase
  test "the Start page section renders beside Appearance and Language and its option saves" do
    sign_in_via_form(users(:user_one))

    visit settings_path(section: "start_page")

    assert_selector "h2#start-page-title", text: "Start page"
    assert_selector "nav.settings-navigation a.active[aria-current=page]", text: "Start page"
    # The other two sections are still reachable, and this one owns the page it
    # points at rather than sharing the bare /settings address.
    assert_selector "nav.settings-navigation a[href='#{settings_path}']", text: "Appearance"
    assert_selector "nav.settings-navigation a[href='#{settings_path(section: "language")}']", text: "Language"

    # Remembering is the default, so it is the checked option on arrival.
    assert_selector "input[name=start_page][value=remember][checked]"
    assert_selector "input[name=start_page][value=universes][checked]", count: 0

    choose "The universes list"
    click_button "Save start page"

    assert_selector ".alert-success", text: /The universes list/
    assert_selector "input[name=start_page][value=universes][checked]"

    # The choice is in the browser, not in this page load, so a reload proves it
    # was stored rather than merely posted.
    visit settings_path(section: "start_page")

    assert_selector "input[name=start_page][value=universes][checked]"
    assert_selector "input[name=start_page][value=remember][checked]", count: 0

    # And it is reversible from the same control.
    choose "My last story"
    click_button "Save start page"

    assert_selector ".alert-success", text: /My last story/
    assert_selector "input[name=start_page][value=remember][checked]"
  end

  test "a reader who signs in again lands on the story they left" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    other_story = stories(:story_alt)

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: universe.slug, id: story)

    assert_selector "h1", text: story.name
    assert_selector ".sidebar-story-name", text: story.name

    # A second sign-in in the same browser. This is the case the per-session
    # story map cannot serve, because it is deliberately wiped whenever a
    # session starts and ends.
    sign_out_and_sign_in(users(:user_one))

    assert_current_path universe_story_path(universe_slug: universe.slug, id: story)
    assert_selector "h1", text: story.name
    assert_selector ".sidebar-story-name", text: story.name

    # Switching to the sibling story moves the destination with it, which is the
    # multi-story behaviour the three Dark stories exist to exercise.
    visit universe_path(universe)
    find("#universe-stories-title ~ .list-group a[aria-label='Open #{other_story.name}']").click
    assert_selector "h1", text: other_story.name

    sign_out_and_sign_in(users(:user_one))

    assert_current_path universe_story_path(universe_slug: universe.slug, id: other_story)
  end

  test "a browser that has never chosen a story lands on the universes list" do
    sign_in_via_form(users(:user_one))

    assert_current_path root_path
    assert_selector "h1", text: "Universes"
  end

  private
    def sign_out_and_sign_in(user)
      sign_out

      # Opened with no referer, so there is no page to be returned to. A page the
      # reader came from always wins over the remembered destination; the
      # preference only answers "and when there is nothing to return to?".
      visit new_session_path
      assert_selector "h1", text: "Sign in"

      fill_in "Email address", with: user.email_address
      fill_in "Password", with: "password"
      assert_field "Email address", with: user.email_address
      click_button "Sign in"
    end

    def sign_out
      click_button "Account"
      page.execute_script("document.querySelector('form.button_to button').click()")
      assert_selector "h1", text: "Sign in"
      assert_equal new_session_path, current_path
    end
end
