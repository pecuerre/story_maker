require "application_system_test_case"

# The appearance grid's column headers are position pills, and the Scene's name
# and Section are behind a Bootstrap popover on hover or keyboard focus. Only a
# browser can show that the popover opens, so the case lives here.
class AppearanceGridTest < ApplicationSystemTestCase
  test "a scene header opens a popover naming its section and scene" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    act = story.sections.create!(name: "Act One")
    sequence = story.sections.create!(name: "The Long Night", parent: act)
    scenes(:scene_two).update!(section: sequence)

    sign_in_via_form(users(:user_one))
    visit universe_story_appearances_path(universe_slug: universe.slug, story_id: story)

    header = find("a.appearance-grid-scene-link[aria-label='Scene 2: Scene two']")
    assert_equal "2", header.find(".appearance-grid-position").text.strip

    page.execute_script("arguments[0].focus()", header.native)

    assert_selector ".popover.show"
    assert_no_selector ".popover.show .popover-header"
    body = find(".popover.show .popover-body").text
    assert_equal [ "Act One", "The Long Night", "Scene: (2) Scene two" ],
      body.split("\n").map(&:strip)
  end
end
