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

  test "the chart lifts one scene and its connector out of the field" do
    universe = universes(:universe_one)
    story = stories(:story_one)
    first_scene = scenes(:scene_one)
    second_scene = scenes(:scene_two)

    sign_in_via_form(users(:user_one))
    visit universe_story_narrative_order_path(universe_slug: universe.slug, story_id: story,
      view: "chart")

    assert_selector "#narrative-order-chart-title", text: "The two orders at once"
    # Two bars per Scene and one connector per Scene, before any pointer movement.
    assert_selector "rect.narrative-chart-bar", count: story.scenes.count * 2
    assert_selector "path.narrative-chart-edge", count: story.scenes.count
    assert_selector ".narrative-chart-detail:not([hidden])", count: 1

    first_bar = find("a[data-narrative-chart-scene='#{first_scene.id}']", match: :first)
    first_bar.hover

    assert_selector "path.narrative-chart-edge[data-narrative-chart-edge='#{first_scene.id}'].is-active"
    assert_selector ".narrative-chart-detail:not([hidden])",
      text: first_scene.name

    second_bar = find("a[data-narrative-chart-scene='#{second_scene.id}']", match: :first)
    second_bar.hover

    assert_selector ".narrative-chart-detail:not([hidden])",
      text: second_scene.name
    assert_no_selector ".narrative-chart-detail:not([hidden])",
      text: first_scene.name
  end
end
