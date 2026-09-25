require "application_system_test_case"

# The sidebars are read as scope blocks, and a block's hue is the only thing
# that tells its blocks apart, so the mapping is asserted in a real browser:
# every context block wears the same hue as the section it introduces, and the
# right utility sidebar's tools scope is the greenish one.
class SidebarScopesTest < ApplicationSystemTestCase
  test "each context block shares the hue of the section it introduces" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: universe.slug, id: story)

    colors = {
      universeContext: background_color("#workspace-navigation .sidebar-context--universe"),
      universeTitle: background_color("#workspace-navigation .sidebar-section--universe .sidebar-section-title"),
      storyContext: background_color("#workspace-navigation .sidebar-context--story"),
      storyTitle: background_color("#workspace-navigation .sidebar-section--story .sidebar-section-title"),
      toolsContext: background_color("#workspace-tools-navigation .sidebar-context--tools"),
      toolsTitle: background_color("#workspace-tools-navigation .sidebar-section--tools .sidebar-section-title")
    }

    assert_equal colors[:universeContext], colors[:universeTitle]
    assert_equal colors[:storyContext], colors[:storyTitle]
    assert_equal colors[:toolsContext], colors[:toolsTitle]

    # Three scopes, three distinct soft backgrounds, none of them a reset value.
    assert_equal 3, colors.values.uniq.size
    assert colors.values.none? { |color| color == "missing" || color == "rgba(0, 0, 0, 0)" }

    # The right column is the greenish one: green leads its channels, while the
    # universe scope leads on blue and the story scope on red.
    _universe_red, universe_green, universe_blue = channels(colors[:universeContext])
    story_red, story_green, _story_blue = channels(colors[:storyContext])
    tools_red, tools_green, tools_blue = channels(colors[:toolsContext])

    assert_operator universe_blue, :>, universe_green
    assert_operator story_red, :>, story_green
    assert_operator tools_green, :>, tools_red
    assert_operator tools_green, :>, tools_blue
  end

  test "the right column owns Configuration and its green context block" do
    universe = universes(:universe_one)

    sign_in_via_form(users(:user_one))
    visit universe_path(universe)

    within "aside.right-sidebar" do
      assert_selector ".sidebar-context--tools"
      assert_equal [ "CONFIGURATION", "COLLABORATION", "ANALYTICS", "AI" ],
        all(".sidebar-section-title").map { |title| title.text.strip }

      within "section[aria-labelledby='configuration-title']" do
        assert_selector "a.sidebar-link[href='#{universe_tags_path(universe_slug: universe.slug)}']", text: "Tags"
        assert_selector "a.sidebar-link[href='#{universe_memberships_path(universe_slug: universe.slug)}']",
          text: "Members"
      end
    end

    # The left column stays about universe and story content only.
    within "aside.workspace-sidebar" do
      assert_no_selector ".sidebar-section--tools"
      assert_no_selector "a", text: "Tags"
      assert_no_selector "a", text: "Members"
    end
  end

  private
    # `evaluate_script` wraps the script in `return ...`, so the probe stays one
    # expression and takes the selector through `arguments[0]` instead of
    # interpolating it into the JavaScript.
    def background_color(selector)
      page.evaluate_script(<<~JS, selector)
        (function (node) { return node ? getComputedStyle(node).backgroundColor : "missing"; })(document.querySelector(arguments[0]))
      JS
    end

    def channels(color)
      color.scan(/\d+/).map(&:to_i)
    end
end
