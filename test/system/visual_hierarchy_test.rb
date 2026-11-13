require "application_system_test_case"

# The 2026-11-13 rendered audit measured two hierarchy defects that only a
# browser can show: peer list rows whose height depended on how much summary
# they happened to carry (98px against 65px), and plain links falling back to
# the browser's black focus outline while controls drew the application's blue
# one. Both are CSS facts, so their assertions read the rendered page rather
# than a class name in the markup.
class VisualHierarchyTest < ApplicationSystemTestCase
  test "a Character row and a Scene row are the same height with a long summary" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    characters(:character_one).update!(
      summary: "A summary long enough to need more than one line in the row, so an unclamped " \
        "second line would make this row taller than its peers in the Scene list."
    )
    scenes(:scene_one).update!(
      description: "A description long enough to need more than one line in the row, so an " \
        "unclamped second line would make this row taller than its peers in the Character list."
    )

    sign_in_via_form(users(:user_one))
    page.driver.browser.manage.window.resize_to(1440, 900)

    visit universe_characters_path(universe_slug: universe.slug)
    character_height = row_height_for(characters(:character_one).name)

    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    scene_height = row_height_for(scenes(:scene_one).name)

    assert_operator (character_height - scene_height).abs, :<=, 2,
      "the Character row (#{character_height}px) and Scene row (#{scene_height}px) should share one density"
  end

  test "a plain link draws the application's primary focus ring" do
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_path(universe_slug: universe.slug, id: story)

    # A keypress first puts the browser in keyboard modality, which is what
    # makes the programmatic focus below match `:focus-visible` rather than the
    # pointer-focused state that deliberately shows no ring.
    page.driver.browser.action.send_keys(:tab).perform
    link = find(".surface-card a:not(.btn)", match: :first)

    focus = page.evaluate_script(<<~JS, link.native)
      (function (node) {
        node.focus({ preventScroll: true })
        var style = getComputedStyle(node)
        return {
          visible: node.matches(":focus-visible"),
          outlineStyle: style.outlineStyle,
          outlineWidth: style.outlineWidth,
          outlineColor: style.outlineColor
        }
      })(arguments[0])
    JS

    assert focus["visible"], "the link should match :focus-visible when reached from the keyboard"
    assert_equal "solid", focus["outlineStyle"]
    assert_equal "2px", focus["outlineWidth"]
    refute_equal "rgb(0, 0, 0)", focus["outlineColor"],
      "the ring should be the application's primary color, not the browser's black fallback"
  end

  private
    def row_height_for(text)
      row = all(".entity-list .entity-row").find { |node| node.has_text?(text) }
      assert row, "expected a row containing #{text.inspect}"

      page.evaluate_script(
        "(function (node) { return node.getBoundingClientRect().height }) (arguments[0])",
        row.native
      )
    end
end
