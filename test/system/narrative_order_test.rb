require "application_system_test_case"

class NarrativeOrderTest < ApplicationSystemTestCase
  test "a signed-in reader compares the scene sequence with the timeline" do
    # A scene whose own time is before its event is the one conflict the page
    # reports, so the browser case proves the definition reaches the rendered row.
    scenes(:scene_one).update!(datetime: "2026-09-11 08:00")
    universe = universes(:universe_one)
    story = stories(:story_one)

    sign_in_via_form(users(:user_one))
    visit universe_story_scenes_path(universe_slug: universe.slug, story_id: story)
    click_link "Narrative order"

    assert_selector "h1", text: "Narrative order"
    assert_selector "#narrative-order-left-title", text: "How the story is told"
    assert_selector "#narrative-order-right-title", text: "When it happens"
    assert_selector "ol.list-group .entity-title", text: "Scene one"
    assert_selector "a", text: "The beginning"
    assert_text "Conflicting time"
    assert_no_selector ".alert-danger"
  end
end
