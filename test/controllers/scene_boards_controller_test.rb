require "test_helper"

class SceneBoardsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  def board_path(story: @story, universe: @universe)
    universe_story_scene_board_path(universe_slug: universe.slug, story_id: story)
  end

  test "the page renders a column per section plus the ungrouped column" do
    get board_path

    assert_response :success
    assert_select "h1", text: "Scene board"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]", board_path, text: "Scene board"
    assert_select "nav.content-tabs a", text: "Scene matrix"
    assert_select "nav.content-tabs a", text: "Scenes"

    assert_select ".scene-board-column", count: 3
    assert_select ".scene-board-column h2", text: "Section one"
    assert_select ".scene-board-column h2", text: "Section one / Section two"
    assert_select ".scene-board-column h2", text: "Ungrouped"
    assert_select ".scene-board-column h2 a[href=?]",
      universe_story_section_path(story_id: @story, id: sections(:section_two)),
      text: "Section one / Section two"
    assert_select ".scene-board-column h2", text: "Ungrouped" do |headings|
      assert_empty headings.first.css("a")
    end
  end

  test "every card links to Scene Details with its narrative position" do
    get board_path

    assert_response :success
    assert_select ".scene-board-card", count: 3
    assert_select ".scene-board-card a[href=?]",
      universe_story_scene_path(story_id: @story, id: scenes(:scene_one)), text: "Scene one"
    assert_select ".scene-board-position[aria-label=?]", "Narrative position 1 of 3"
    assert_select ".scene-board-position[aria-label=?]", "Narrative position 3 of 3"
  end

  test "a column states its scene count and an empty column says so" do
    @story.sections.create!(name: "Empty section", position: 2)

    get board_path

    assert_response :success
    assert_select ".scene-board-column", count: 4
    assert_select ".scene-board-column-header .record-count", text: "(1 scene)"
    assert_select ".scene-board-empty", text: "No scenes here"
  end

  test "the board offers writers the same move and regroup actions as the list" do
    get board_path

    assert_response :success
    assert_select ".scene-board-card", count: 3
    assert_select ".scene-board-card details.scene-board-regroup", count: 3
    assert_select "form[action=?]", group_universe_story_scenes_path(story_id: @story), count: 3
    assert_select "select[name=section_id]", count: 3
    assert_select "select[name=section_id] option[value=?]", "", text: "Ungrouped"
    assert_select "input[name=return_to][value=?]", SceneBoard::RETURN_TO, count: 3

    # The boundary state is the whole sequence's, exactly as the list's is.
    assert_select "button[data-scene-board-move=up][disabled]", count: 1
    assert_select "button[data-scene-board-move=down][disabled]", count: 1
  end

  test "a move from the board reorders the story and returns to the board" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)),
      params: { direction: "down", return_to: SceneBoard::RETURN_TO }

    assert_redirected_to universe_story_scene_board_url(universe_slug: @universe.slug, story_id: @story)
    assert_equal [ scenes(:scene_two), scenes(:scene_one), scenes(:scene_three) ],
      @story.scenes.reorder(:position, :id).to_a
  end

  test "a boundary move from the board stays put and says so" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)),
      params: { direction: "up", return_to: SceneBoard::RETURN_TO }

    assert_redirected_to universe_story_scene_board_url(universe_slug: @universe.slug, story_id: @story)
    assert_equal 0, scenes(:scene_one).reload.position
    assert_match(/already first/, flash[:alert])
  end

  test "a regroup from the board changes only the section and returns to the board" do
    scene = scenes(:scene_one)
    original_position = scene.position

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: scene.id, section_id: sections(:section_two).id, return_to: SceneBoard::RETURN_TO }

    assert_redirected_to universe_story_scene_board_url(universe_slug: @universe.slug, story_id: @story)
    assert_equal sections(:section_two), scene.reload.section
    assert_equal original_position, scene.position
    assert_match(/narrative position did not change/, flash[:notice])
  end

  test "an ungrouping from the board keeps the scene in narrative order" do
    scene = scenes(:scene_one)

    patch group_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story),
      params: { scene_id: scene.id, section_id: "", return_to: SceneBoard::RETURN_TO }

    assert_redirected_to universe_story_scene_board_url(universe_slug: @universe.slug, story_id: @story)
    assert_nil scene.reload.section
    assert_equal 0, scene.position
  end

  test "an unrecognized return destination falls back to the list" do
    patch move_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one)),
      params: { direction: "down", return_to: "https://example.com/elsewhere" }

    assert_redirected_to universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story)
  end

  test "a read-only member sees no card control" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private board",
      slug: "private-board", private: true)
    private_story = Story.create!(universe: private_universe, name: "Board story")
    private_story.scenes.create!(name: "A private scene")
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))

    get universe_story_scene_board_path(universe_slug: private_universe.slug, story_id: private_story)

    assert_response :success
    assert_select ".scene-board form", count: 0
    assert_select ".scene-board button", count: 0
    assert_select ".scene-board select", count: 0
  end

  test "a guest can read the board of a public universe" do
    sign_out

    get board_path

    assert_response :success
    assert_select ".scene-board", count: 1
    assert_select ".scene-board form", count: 0
    assert_select ".scene-board button", count: 0
    assert_select ".scene-board select", count: 0
  end

  test "a story with no scenes gets the empty state rather than empty columns" do
    empty = @universe.stories.create!(name: "No scenes")

    get board_path(story: empty)

    assert_response :success
    assert_select ".empty-title", text: "No scenes yet"
    assert_select ".scene-board", count: 0
  end

  test "another universe's story is a 404" do
    get universe_story_scene_board_path(universe_slug: universes(:universe_two).slug, story_id: @story)

    assert_response :not_found
  end
end
