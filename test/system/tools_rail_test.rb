require "application_system_test_case"

# The collapsible tools rail is a browser preference with a server-rendered
# first paint. Only a browser can show the width change, the control's state,
# the tooltips that replace the hidden labels, and that a later request still
# renders the chosen state from the cookie.
class ToolsRailTest < ApplicationSystemTestCase
  setup do
    @user = users(:user_one)
    @universe = universes(:universe_one)
    sign_in_via_form(@user)
    page.driver.browser.manage.window.resize_to(1280, 900)
  end

  teardown do
    page.driver.browser.manage.window.resize_to(1400, 1400) if page.driver.browser
  end

  test "the rail collapses, keeps its names, and survives the next request" do
    visit universe_characters_path(universe_slug: @universe.slug)

    toggle = find(".tools-rail-toggle")
    assert_equal "true", toggle["aria-expanded"]
    assert_equal 204, rail_width

    toggle.click

    assert_selector ".workspace-shell.tools-rail-collapsed"
    assert_equal "false", find(".tools-rail-toggle")["aria-expanded"]
    assert_equal "Expand tools", find(".tools-rail-toggle [data-tools-rail-label]").text
    assert_in_delta 48, rail_width, 1

    # The label is clipped rather than removed, so the link keeps its accessible
    # name, and the controller supplies the pointer-visible equivalent.
    label_width = evaluate_script(<<~JS)
      (function () {
        var label = document.querySelector(".right-sidebar .sidebar-link-label")
        return label.getBoundingClientRect().width
      })()
    JS
    assert_operator label_width, :<=, 1
    assert_equal "Tags", find(".right-sidebar .sidebar-link", match: :first)["title"]

    # Only the tools rail changes. The left workspace navigation keeps its width
    # and its visible labels.
    left_rail = evaluate_script(<<~JS)
      (function () {
        var rail = document.querySelector(".workspace-sidebar")
        var label = rail.querySelector(".sidebar-link-label")
        return {
          width: Math.round(rail.getBoundingClientRect().width),
          labelWidth: Math.round(label.getBoundingClientRect().width),
          title: label.closest(".sidebar-link").title
        }
      })()
    JS
    assert_equal 232, left_rail["width"]
    assert_operator left_rail["labelWidth"], :>, 20
    assert_equal "", left_rail["title"]

    # The next request renders the collapsed class from the cookie, so the
    # reader does not have to collapse it again on every page.
    click_link "Tags", match: :first
    assert_selector ".workspace-shell.tools-rail-collapsed"
    assert_equal "false", find(".tools-rail-toggle")["aria-expanded"]

    find(".tools-rail-toggle").click

    assert_no_selector ".workspace-shell.tools-rail-collapsed"
    assert_equal "true", find(".tools-rail-toggle")["aria-expanded"]
    assert_equal 204, rail_width
  end

  test "the toggle is not offered while the tools are a drawer" do
    visit universe_characters_path(universe_slug: @universe.slug)

    page.driver.browser.manage.window.resize_to(991, 900)

    assert_selector ".tools-rail-toggle", visible: false
    assert_selector ".mobile-workspace-bar", visible: true
  end

  private

  def rail_width
    evaluate_script("document.querySelector('.right-sidebar').getBoundingClientRect().width").round
  end
end
