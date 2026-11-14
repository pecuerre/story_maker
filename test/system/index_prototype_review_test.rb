require "application_system_test_case"

# The 2026-11-14 review of the Index prototype measured corrections that only a
# rendered browser can show: a translated mobile scope line that used to clip,
# a dark destructive menu entry that used to be dim, and the hit area of the
# two row controls inside the 46px row. The kicker copy is covered by
# `workspace_locale_test.rb`; these are the layout and colour facts.
class IndexPrototypeReviewTest < ApplicationSystemTestCase
  test "the Spanish scope line wraps the story whole at phone width" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    universe.update!(name: "Winden")
    story.update!(name: "Bethany Dark")

    sign_in_via_form(users(:user_one))
    visit settings_path(section: "language")
    choose "Español"
    click_button "Save language"
    assert_selector "html[lang='es']"

    # Selecting the story is what puts it in the session the mobile bar reads.
    visit universe_story_path(universe_slug: universe.slug, id: story)
    page.driver.browser.manage.window.resize_to(390, 844)
    visit universe_characters_path(universe_slug: universe.slug)

    assert_no_horizontal_overflow

    context = rect(".mobile-workspace-context")
    universe_line = rect(".mobile-workspace-universe")
    story_line = rect(".mobile-workspace-story")

    assert_operator context["scrollWidth"], :<=, context["width"] + 1,
      "the scope line must wrap instead of clipping: #{context.inspect}"
    assert_operator story_line["top"], :>=, universe_line["bottom"] - 1,
      "the story should take its own line when both names do not fit"
    assert_operator story_line["height"], :<=, 24,
      "the story name itself should stay on one line: #{story_line.inspect}"
  end

  test "a dark row menu keeps its destructive text legible" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    visit settings_path(section: "appearance")
    choose "Dark"
    click_button "Save theme"
    assert_selector "html[data-bs-theme='dark']"

    visit universe_characters_path(universe_slug: universe.slug)
    assert_selector ".entity-row .dropdown-item.text-danger", visible: :all

    colors = page.evaluate_script(<<~JS)
      (function () {
        var item = document.querySelector(".entity-row .dropdown-item.text-danger")
        var probe = document.createElement("span")
        probe.style.color = "var(--bs-danger-text-emphasis)"
        document.body.appendChild(probe)
        var expected = getComputedStyle(probe).color
        probe.remove()
        return { actual: getComputedStyle(item).color, expected: expected }
      })()
    JS

    assert_equal colors["expected"], colors["actual"],
      "the dark theme should use its danger text-emphasis rather than the light theme's deep red"
  end

  test "the row controls keep a 40px touch target at phone width" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(390, 844)
    visit universe_characters_path(universe_slug: universe.slug)

    assert_no_horizontal_overflow
    row = all(".entity-list .entity-row").first
    assert row, "the Characters list should render a row"

    hit = page.evaluate_script(<<~JS, row.native)
      (function (row) {
        var link = row.querySelector(".details-link")
        var toggle = row.querySelector(".dropdown-toggle")
        var linkRect = link.getBoundingClientRect()
        var toggleRect = toggle.getBoundingClientRect()
        // The painted boxes are 19px and 30px high, so a point a few pixels
        // above each is outside the control's own box but inside the hit area
        // it paints from the row's padding.
        var aboveLink = document.elementFromPoint(linkRect.left + 10, linkRect.top - 4)
        var aboveToggle = document.elementFromPoint(
          toggleRect.left + toggleRect.width / 2,
          toggleRect.top - 4
        )
        return {
          rowHeight: row.getBoundingClientRect().height,
          linkHitHeight: parseFloat(getComputedStyle(link, "::after").height),
          toggleHitHeight: parseFloat(getComputedStyle(toggle, "::before").height),
          details: aboveLink === link || link.contains(aboveLink),
          menu: aboveToggle === toggle || toggle.contains(aboveToggle)
        }
      })(arguments[0])
    JS

    assert_operator hit["rowHeight"], :>=, 40,
      "the row itself is the first touch target: #{hit.inspect}"
    assert_operator hit["linkHitHeight"], :>=, 39.5,
      "the Details hit area should reach the row's 40px target: #{hit.inspect}"
    assert_operator hit["toggleHitHeight"], :>=, 39.5,
      "the row menu hit area should reach the row's 40px target: #{hit.inspect}"
    assert hit["details"],
      "a point above the painted Details text should still reach the link: #{hit.inspect}"
    assert hit["menu"],
      "a point above the painted menu button should still reach it: #{hit.inspect}"
  end

  private
    def assert_no_horizontal_overflow
      dimensions = page.evaluate_script(<<~JS)
        ({ scroll: document.documentElement.scrollWidth,
           client: document.documentElement.clientWidth })
      JS
      assert_operator dimensions["scroll"], :<=, dimensions["client"] + 1,
        "the document should not scroll sideways: #{dimensions.inspect}"
    end

    def rect(selector)
      page.evaluate_script(<<~JS, selector)
        (function (selector) {
          var node = document.querySelector(selector)
          var box = node.getBoundingClientRect()
          return {
            top: box.top, bottom: box.bottom, left: box.left, right: box.right,
            width: box.width, height: box.height,
            scrollWidth: node.scrollWidth, scrollHeight: node.scrollHeight
          }
        })(arguments[0])
      JS
    end
end
