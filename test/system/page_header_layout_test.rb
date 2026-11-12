require "application_system_test_case"

# The shared page header puts a page's identity on the left and its actions on
# the right, and the Story overview is its widest user: a title, a description,
# and up to eight controls. The baseline measured that header at 1440 CSS pixels
# pushing its actions into the right sidebar while the description collapsed to
# zero width, and a Spanish Story at 768 CSS pixels making the document 1278
# pixels wide. Both are layout facts only a rendered browser can show, so they
# live here rather than in a request test.
class PageHeaderLayoutTest < ApplicationSystemTestCase
  test "the signed-in Story header keeps its copy and actions inside the main column" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit universe_story_path(universe_slug: universe.slug, id: story)

    assert_selector ".page-header .page-actions .btn", minimum: 1
    assert_no_horizontal_overflow
    assert_header_fits
    assert_operator description_width, :>=, 240,
      "the Story description must keep a readable block instead of collapsing beside the actions"
  end

  test "a long Story name and description still wrap at desktop width" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    story.update!(
      name: "A remarkably long story title that has to wrap instead of widening the page",
      description: "A description long enough that a header which lets it keep its natural width would " \
        "push the action area out of the main column and make the whole document scroll sideways."
    )

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit universe_story_path(universe_slug: universe.slug, id: story)

    assert_no_horizontal_overflow
    assert_header_fits
  end

  test "the Spanish Story header fits a tablet width" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit settings_path(section: "language")
    choose "Español"
    click_button "Save language"
    assert_selector "html[lang='es']"

    page.driver.browser.manage.window.resize_to(768, 1024)
    visit universe_story_path(universe_slug: universe.slug, id: story)

    assert_selector "html[lang='es']"
    assert_no_horizontal_overflow
    assert_header_fits
  end

  test "a phone width stacks the Story actions under the copy" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(390, 844)
    visit universe_story_path(universe_slug: universe.slug, id: story)

    assert_no_horizontal_overflow
    assert_header_fits

    copy_bottom = rect(".page-header-copy")["bottom"]
    actions_top = rect(".page-actions")["top"]
    assert_operator actions_top, :>=, copy_bottom - 1,
      "the actions should wrap below the copy rather than sharing its row at phone width"
  end

  test "a desktop window at 200 percent zoom, which reports half the CSS pixels, still fits" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    # Chrome's page zoom shrinks the CSS-pixel viewport, so a 1440-pixel window
    # at 200 percent lays out as a 720-pixel one. This checks the medium width
    # between the phone and `md` cases, where the header stacks vertically.
    page.driver.browser.manage.window.resize_to(720, 900)
    visit universe_story_path(universe_slug: universe.slug, id: story)

    assert_no_horizontal_overflow
    assert_header_fits

    copy_bottom = rect(".page-header-copy")["bottom"]
    actions_top = rect(".page-actions")["top"]
    assert_operator actions_top, :>=, copy_bottom - 1,
      "the actions should wrap below the copy at a medium width"
  end

  test "another page header shares the same fit at desktop width" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(1440, 900)
    visit universe_characters_path(universe_slug: universe.slug)

    assert_selector ".page-header .page-actions .btn", minimum: 1
    assert_no_horizontal_overflow
    assert_header_fits
  end

  private
    def assert_header_fits
      header = rect(".page-header")
      main = rect("#main-content")
      copy = rect(".page-header-copy")
      actions = rect(".page-actions")

      assert_operator actions["right"], :<=, header["right"] + 1,
        "the header actions (#{actions.inspect}) should stay inside the header (#{header.inspect})"
      assert_operator actions["right"], :<=, main["right"] + 1,
        "the header actions (#{actions.inspect}) should stay inside the main column (#{main.inspect})"
      assert_operator copy["left"], :>=, header["left"] - 1,
        "the header copy (#{copy.inspect}) should stay inside the header (#{header.inspect})"

      # The two regions share a row on desktop and stack on a phone, so the
      # horizontal separation is only meaningful when they overlap vertically.
      same_row = copy["top"] < actions["bottom"] && actions["top"] < copy["bottom"]
      if same_row
        assert_operator copy["right"], :<=, actions["left"] + 1,
          "the header copy (#{copy.inspect}) should not run under the actions (#{actions.inspect})"
      end

      scroll_width, client_width = page.evaluate_script(<<~JS)
        (function () {
          var header = document.querySelector(".page-header")
          return [header.scrollWidth, header.clientWidth]
        })()
      JS
      assert_operator scroll_width, :<=, client_width + 1,
        "the header should not overflow its own box"
    end

    def rect(selector)
      page.evaluate_script(<<~JS, selector)
        (function (node) {
          if (!node) return null
          var box = node.getBoundingClientRect()
          return { left: box.left, right: box.right, top: box.top, bottom: box.bottom, width: box.width }
        })(document.querySelector(arguments[0]))
      JS
    end

    def description_width
      page.evaluate_script(
        "(function (node) { return node ? node.getBoundingClientRect().width : 0 })(document.querySelector('.page-description'))"
      )
    end

    def assert_no_horizontal_overflow
      scroll_width, viewport_width = page.evaluate_script(
        "[document.documentElement.scrollWidth, window.innerWidth]"
      )

      assert_operator scroll_width, :<=, viewport_width + 1
    end
end
