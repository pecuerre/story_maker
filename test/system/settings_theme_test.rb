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

    open_universe(universe)

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

  # Bootstrap's outline-button mixin bakes the *light* theme's color into the
  # component's variables and never re-tints them for the dark theme, so this is
  # a theme defect that only a rendered page can show. The Story header is
  # where the baseline found it: outline-primary and outline-secondary text at
  # 2.45:1 and 3.10:1 on the dark canvas. The ratio is asserted here rather than
  # the color, so a palette change is free to move the value as long as the
  # button stays legible.
  test "dark theme keeps the Story header's outline buttons legible" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit settings_path
    choose "Dark"
    click_button "Save theme"

    # The preference is applied by a full document load, so the save has to land
    # before the next navigation rather than race it.
    assert_selector "h1", text: "Settings"
    assert_equal "dark", theme_attribute

    visit universe_story_path(universe_slug: universe.slug, id: story)
    assert_equal "dark", theme_attribute
    canvas = background_color("body")

    %w[primary secondary].each do |variant|
      selector = ".btn-outline-#{variant}"
      button = find(selector, match: :first)

      assert_operator contrast_ratio(computed_style(button, "color"), canvas), :>=, 4.5,
        "the dark theme's #{variant} outline label should meet the 4.5:1 text target"
      assert_operator contrast_ratio(computed_style(button, "border-top-color"), canvas), :>=, 3.0,
        "the dark theme's #{variant} outline boundary should meet the 3:1 non-text target"

      button.hover
      sleep 0.25 # the button transitions its colors for .15s
      fill = computed_style(button, "background-color")
      assert_not_equal "rgba(0, 0, 0, 0)", fill,
        "hovering the dark theme's #{variant} outline button should paint a fill, not stay transparent"
      assert_operator contrast_ratio(computed_style(button, "color"), fill), :>=, 4.5,
        "hovering the dark theme's #{variant} outline button should keep its label readable"
    end
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

    # The property is read from *this* element rather than from the first CSS
    # match, because several buttons of one variant exist on the page and a hidden
    # one would answer for the visible button the case is measuring.
    def computed_style(element, property)
      page.execute_script(
        "return getComputedStyle(arguments[0]).getPropertyValue(arguments[1])",
        element.native, property
      )
    end

    # WCAG 2.1 contrast: the relative luminance of each color, then the ratio
    # between the lighter and the darker one. The 4.5:1 and 3:1 targets the
    # outline-button case asserts are the AA thresholds for normal-size text and
    # for a control boundary.
    def contrast_ratio(first, second)
      lighter, darker = [ relative_luminance(first), relative_luminance(second) ].sort.reverse
      (lighter + 0.05) / (darker + 0.05)
    end

    def relative_luminance(color)
      channels = color.scan(/([\d.]+)(%?)/).first(3).map do |channel, percent|
        channel.to_f / (percent.empty? ? 255.0 : 100.0)
      end
      linear = channels.map { |channel| channel <= 0.03928 ? channel / 12.92 : ((channel + 0.055) / 1.055) ** 2.4 }
      (0.2126 * linear[0]) + (0.7152 * linear[1]) + (0.0722 * linear[2])
    end

    # Perceived brightness from the computed rgb() channels: enough to say one
    # canvas is the dark one without restating a Bootstrap value in the test.
    def luminance(color)
      red, green, blue = color.scan(/\d+/).first(3).map(&:to_i)
      (0.2126 * red) + (0.7152 * green) + (0.0722 * blue)
    end
end
