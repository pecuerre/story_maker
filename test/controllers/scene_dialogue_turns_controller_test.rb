require "test_helper"

# Dialogue turn mutations are JSON-only (ADR 0011): the shared modal submits
# them itself, a rejection is a 422 error hash the modal renders, and an HTML
# request is refused before anything is written. Every action needs a session and
# the shared Universe write policy, and every record is loaded through the
# authorized Universe → Story → Scene → Element path.
class SceneDialogueTurnsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @element = scene_elements(:dialogue_one)
    @turn_path = universe_story_scene_scene_element_scene_dialogue_turns_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element
    )
    sign_in_as(users(:user_one))
  end

  def private_element
    universe = Universe.create!(owner: users(:user_one), name: "Private turns", slug: "private-turns", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    scene = story.scenes.create!(name: "Private scene")
    speaker = universe.characters.create!(name: "Private speaker")
    element = scene.scene_elements.create!(name: "Private dialogue", kind: SceneElement::DIALOGUE,
      character_ids: [ speaker.id ])
    [ universe, story, scene, element, speaker ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  def turn_url(turn, **options)
    universe_story_scene_scene_element_scene_dialogue_turn_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element, id: turn, **options
    )
  end

  def turn_move_url(turn, direction, **options)
    move_universe_story_scene_scene_element_scene_dialogue_turn_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element, id: turn, direction: direction, **options
    )
  end

  test "creates a turn at the end of the element sequence" do
    assert_difference("SceneDialogueTurn.count", 1) do
      post @turn_path, params: {
        scene_dialogue_turn: { speaker_id: characters(:character_three).id, body: "Count with me." }
      }, as: :json
    end

    created = @element.scene_dialogue_turns.order(:id).last
    assert_response :created
    assert_equal "Count with me.", created.body
    response_body = response.parsed_body
    assert_equal universe_story_scene_scene_element_scene_dialogue_turn_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element, id: created
    ), response_body["update_url"]
    assert_equal move_universe_story_scene_scene_element_scene_dialogue_turn_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element, id: created, direction: "up"
    ), response_body["move_up_url"]
    assert_equal move_universe_story_scene_scene_element_scene_dialogue_turn_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element, id: created, direction: "down"
    ), response_body["move_down_url"]
    assert_equal universe_story_scene_scene_element_scene_dialogue_turn_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene,
      scene_element_id: @element, id: created
    ), response_body["destroy_url"]
    assert_equal @element.scene_dialogue_turns.count - 1, created.position
    assert_equal (0...@element.scene_dialogue_turns.count).to_a,
      @element.scene_dialogue_turns.reorder(:position, :id).pluck(:position)
  end

  test "a turn needs a same-universe speaker and a body is optional" do
    assert_difference("SceneDialogueTurn.count", 1) do
      post @turn_path, params: {
        scene_dialogue_turn: { speaker_id: characters(:character_one).id }
      }, as: :json
    end

    assert_response :created
    assert_predicate @element.scene_dialogue_turns.order(:id).last.body, :blank?
  end

  test "a turn from another universe's speaker is a 422 rather than a cross-scope write" do
    outsider = universes(:universe_two).characters.create!(name: "Outsider")

    assert_no_difference("SceneDialogueTurn.count") do
      post @turn_path, params: {
        scene_dialogue_turn: { speaker_id: outsider.id, body: "No" }
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the scene's universe" ],
      response.parsed_body["speaker"]
  end

  test "an unknown speaker id is a 422 rather than a foreign key error" do
    assert_no_difference("SceneDialogueTurn.count") do
      post @turn_path, params: {
        scene_dialogue_turn: { speaker_id: 0, body: "Ghost" }
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_includes response.parsed_body["speaker"], "must exist"
    assert_includes response.parsed_body["speaker"], "can't be blank"
  end

  test "a narration element cannot carry a turn" do
    narration = scene_elements(:narration_one)
    narration_path = universe_story_scene_scene_element_scene_dialogue_turns_path(
      universe_slug: @universe.slug, story_id: @story, scene_id: @scene, scene_element_id: narration
    )

    assert_no_difference("SceneDialogueTurn.count") do
      post narration_path, params: {
        scene_dialogue_turn: { speaker_id: characters(:character_one).id, body: "No" }
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "a narration element cannot carry a turn" ],
      response.parsed_body["base"]
  end

  test "updates the line without moving the turn" do
    turn = scene_dialogue_turns(:turn_one)
    original_position = turn.position

    patch turn_url(turn), params: {
      scene_dialogue_turn: { body: "One, two, three. Again." }
    }, as: :json

    assert_response :success
    turn.reload
    assert_equal "One, two, three. Again.", turn.body
    assert_equal original_position, turn.position
  end

  test "an edit that does not mention the speaker keeps it" do
    turn = scene_dialogue_turns(:turn_one)
    speaker_id = turn.speaker_id

    patch turn_url(turn), params: { scene_dialogue_turn: { body: "Retake" } }, as: :json

    assert_response :success
    assert_equal speaker_id, turn.reload.speaker_id
  end

  test "moves a turn up and down in its own sequence" do
    first, second = @element.scene_dialogue_turns.reorder(:position, :id).first(2)

    patch turn_move_url(second, "up"), as: :json

    assert_response :success
    assert_equal [ second, first ], @element.scene_dialogue_turns.reorder(:position, :id).first(2)
    assert_equal [ 0, 1 ], @element.scene_dialogue_turns.reorder(:position, :id).pluck(:position)

    patch turn_move_url(second, "down"), as: :json

    assert_response :success
    assert_equal [ first, second ], @element.scene_dialogue_turns.reorder(:position, :id).first(2)
  end

  test "moving past either end of the sequence is a no-op" do
    first = @element.scene_dialogue_turns.reorder(:position, :id).first
    last = @element.scene_dialogue_turns.reorder(:position, :id).last

    patch turn_move_url(first, "up"), as: :json
    assert_response :success
    assert_equal 0, first.reload.position

    patch turn_move_url(last, "down"), as: :json
    assert_response :success
    assert_equal 1, last.reload.position
    assert_equal [ 0, 1 ], @element.scene_dialogue_turns.reorder(:position, :id).pluck(:position)
  end

  test "a move needs a known direction" do
    turn = scene_dialogue_turns(:turn_one)

    patch turn_move_url(turn, "sideways"), as: :json

    assert_response :bad_request
    assert_equal 0, turn.reload.position
  end

  test "deleting a turn closes the gap and keeps its speaker" do
    turn = scene_dialogue_turns(:turn_one)
    speaker_id = turn.speaker_id

    assert_no_difference("SceneDialogueTurn.with_deleted.count") do
      delete turn_url(turn), as: :json
    end

    assert_response :no_content
    assert turn.reload.deleted?, "the turn is soft-deleted, not removed"
    assert_equal [ 0 ], @element.scene_dialogue_turns.reorder(:position, :id).pluck(:position)
    assert_equal speaker_id, Character.find(speaker_id).id, "a shared character survives its turn"
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneDialogueTurn.count") do
      post @turn_path, params: { scene_dialogue_turn: { speaker_id: characters(:character_three).id,
        body: "From a browser form" } }
    end
    assert_response :not_acceptable

    assert_no_difference("SceneDialogueTurn.count") do
      patch turn_url(scene_dialogue_turns(:turn_one)), params: { scene_dialogue_turn: { body: "Renamed" } }
    end
    assert_response :not_acceptable

    assert_no_difference("SceneDialogueTurn.count") do
      delete turn_url(scene_dialogue_turns(:turn_one))
    end
    assert_response :not_acceptable

    patch turn_move_url(scene_dialogue_turns(:turn_one), "down")
    assert_response :not_acceptable
  end

  test "guests are sent to sign in and read-only members are refused" do
    universe, story, scene, element, speaker = private_element
    turn = element.scene_dialogue_turns.create!(speaker: speaker, body: "Private turn")
    sign_in_read_only_member(universe)

    assert_no_difference("SceneDialogueTurn.count") do
      post universe_story_scene_scene_element_scene_dialogue_turns_url(
        universe_slug: universe.slug, story_id: story, scene_id: scene, scene_element_id: element),
        params: { scene_dialogue_turn: { speaker_id: speaker.id, body: "No" } }, as: :json
    end
    assert_response :forbidden

    assert_equal "Private turn", turn.reload.body

    sign_out

    assert_no_difference("SceneDialogueTurn.count") do
      post universe_story_scene_scene_element_scene_dialogue_turns_url(
        universe_slug: universe.slug, story_id: story, scene_id: scene, scene_element_id: element),
        params: { scene_dialogue_turn: { speaker_id: speaker.id, body: "Guest" } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "a turn of another element is not found" do
    other_scene = @universe.stories.create!(name: "Other story").scenes.create!(name: "Other scene")
    other_element = other_scene.scene_elements.create!(name: "Other dialogue", kind: SceneElement::DIALOGUE,
      character_ids: [ characters(:character_three).id ])
    other_turn = other_element.scene_dialogue_turns.create!(speaker: characters(:character_three), body: "Other turn")

    patch turn_url(other_turn), params: { scene_dialogue_turn: { body: "Hijacked" } }, as: :json
    assert_response :not_found

    assert_equal "Other turn", other_turn.reload.body
  end

  test "the collection is not a read action because turns are read with their element" do
    get @turn_path

    assert_response :not_found
  end
end
