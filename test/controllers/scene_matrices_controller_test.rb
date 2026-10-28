require "test_helper"

class SceneMatricesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def matrix_path(story: @story, universe: @universe)
    universe_story_scene_matrix_path(universe_slug: universe.slug, story_id: story)
  end

  test "the page renders every scene as a row with every fact column" do
    get matrix_path

    assert_response :success
    assert_select "h1", text: "Scene matrix"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]", matrix_path, text: "Scene matrix"
    assert_select "nav.content-tabs a", text: "Scenes"
    assert_select "nav.content-tabs a", text: "Appearances"

    assert_select ".scene-matrix thead th", count: 9
    assert_select ".scene-matrix thead th", text: "Scene tags"
    assert_select ".scene-matrix thead th", text: "Point of view"
    assert_select ".scene-matrix thead th", text: "Characters take part"

    assert_select ".scene-matrix tbody tr", count: 3
    assert_select ".scene-matrix tbody th a.scene-matrix-scene-link", text: "Scene one"
    assert_select ".scene-matrix-position[aria-label=?]", "Narrative position 1 of 3"
    assert_select ".scene-matrix tbody th a[href=?]",
      universe_story_scene_path(story_id: @story, id: scenes(:scene_one)), text: "Scene one"
  end

  test "a row states the section path, tags, point of view, time, events, and counts" do
    scenes(:scene_two).update!(pov_character: characters(:character_one))

    get matrix_path

    assert_response :success
    first, second, third = css_select(".scene-matrix tbody tr")

    assert_equal [
      "1 Scene one",
      "Section one",
      "Scene tag one Scene tag two",
      "No point of view recorded",
      "2026-09-11 09:00",
      "The beginning - 2026-09-11 09:00",
      "4",
      "38",
      "3"
    ], first.css("th, td").map { |cell| cell.text.squish }

    assert_equal "Section one / Section two", second.css("td")[0].text.squish
    assert_equal "No tags", second.css("td")[1].text.squish
    assert_equal "Character one", second.css("td")[2].text.squish
    assert_equal "No in-world time recorded", second.css("td")[3].text.squish
    assert_equal "The end - 2026-09-11 10:00", second.css("td")[4].text.squish

    assert_equal "Ungrouped", third.css("td")[0].text.squish
    assert_equal "No events linked", third.css("td")[4].text.squish
  end

  test "event links open the universe event" do
    get matrix_path

    assert_response :success
    assert_select ".scene-matrix a[href=?]",
      universe_event_path(universe_slug: @universe.slug, id: events(:event_one)),
      text: "The beginning - 2026-09-11 09:00"
  end

  test "the matrix is read-only" do
    get matrix_path

    assert_response :success
    assert_select ".scene-matrix form", count: 0
    assert_select ".scene-matrix button", count: 0
    assert_select ".scene-matrix input", count: 0
  end

  test "a guest can read the matrix of a public universe" do
    sign_out

    get matrix_path

    assert_response :success
    assert_select ".scene-matrix", count: 1
  end

  test "a story with no scenes gets the empty state rather than an empty table" do
    empty = @universe.stories.create!(name: "No scenes")

    get matrix_path(story: empty)

    assert_response :success
    assert_select ".empty-title", text: "No scenes yet"
    assert_select ".scene-matrix", count: 0
  end

  test "another universe's story is a 404" do
    get universe_story_scene_matrix_path(universe_slug: universes(:universe_two).slug, story_id: @story)

    assert_response :not_found
  end
end
