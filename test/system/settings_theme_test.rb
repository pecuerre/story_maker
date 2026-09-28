require "application_system_test_case"

# The theme is the one place where the server's answer and the browser's paint are
# the same feature: the layout writes `data-bs-theme` onto the root element and
# Bootstrap's own variables do the rest. Only a real browser can show that the
# compiled CSS follows the attribute, that the chosen card reads as chosen, and
# that the choice survives a navigation, so this lives here rather than in a
# request test.
class SettingsThemeTest < ApplicationSystemTestCase
  test "choosing dark repaints the workspace and the choice follows to another page" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    visit universe_url(universe)

    light_background = background_color("body")
    assert_equal "light", theme_attribute

    click_button "Account"
    click_link "Settings"

    assert_current_path settings_path
    assert_selector "h1", text: "Settings"
    assert_selector "nav.settings-navigation a.active[aria-current=page]", text: "Appearance"
    assert_checked_field "Light", checked: true

    choose "Dark"
    click_button "Save theme"

    assert_selector "h1", text: "Settings"
    assert_checked_field "Dark", checked: true
    assert_equal "dark", theme_attribute
    # The page is not only labelled dark: Bootstrap's own variables changed, so
    # the canvas behind the content is the dark one.
    dark_background = background_color("body")
    assert_not_equal light_background, dark_background
    assert_operator luminance(dark_background), :<, luminance(light_background)

    # The choice belongs to the browser, so it is still there on the next page,
    # including the page that opened the workspace.
    click_link "Universe Maker"

    assert_current_path root_path
    assert_equal "dark", theme_attribute
    assert_equal dark_background, background_color("body")

    click_link universe.name

    assert_selector "h1", text: universe.name
    assert_equal "dark", theme_attribute
    assert_equal dark_background, background_color("body")
  end

  test "the settings page reaches a guest and switching back to light repaints" do
    sign_in_via_form(users(:user_one))
    visit settings_path
    choose "Dark"
    click_button "Save theme"
    dark_background = background_color("body")

    choose "Light"
    click_button "Save theme"

    assert_checked_field "Light", checked: true
    assert_equal "light", theme_attribute
    assert_not_equal dark_background, background_color("body")
  end

  test "the go back action returns to the page settings was opened from" do
    universe = universes(:universe_one)

    visit universe_url(universe)
    click_button "Account"
    click_link "Settings"

    assert_current_path settings_path
    click_link "Go back"

    assert_current_path universe_url(universe)
    assert_selector "h1", text: universe.name
  end

  private
    def theme_attribute
      page.evaluate_script("document.documentElement.getAttribute('data-bs-theme')")
    end

    def background_color(selector)
      page.evaluate_script(<<~JS, selector)
        (function (node) { return node ? getComputedStyle(node).backgroundColor : "missing"; })(document.querySelector(arguments[0]))
      JS
    end

    # Perceived brightness from the computed rgb() channels: enough to say one
    # canvas is the dark one without restating a Bootstrap value in the test.
    def luminance(color)
      red, green, blue = color.scan(/\d+/).first(3).map(&:to_i)
      (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    end
end
