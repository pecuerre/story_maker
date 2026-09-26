require "test_helper"

# Scene Element mutations are JSON-only (ADR 0011): the shared modal submits
# them itself, a rejection is a 422 error hash the modal renders, and an HTML
# request is refused before anything is written. Every action needs a session and
# the shared Universe write policy, and every record is loaded through the
# authorized Universe → Story → Scene path.
class SceneElementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @elements_path = universe_story_scene_scene_elements_path(universe_slug: @universe.slug,
      story_id: @story, scene_id: @scene)
    sign_in_as(users(:user_one))
  end

  def private_scene
    universe = Universe.create!(owner: users(:user_one), name: "Private elements", slug: "private-elements", private: true)
    story = Story.create!(universe: universe, name: "Private story")
    [ universe, story, story.scenes.create!(name: "Private scene") ]
  end

  def sign_in_read_only_member(universe)
    UniverseMembership.create!(universe: universe, user: users(:user_two), access_level: :read)
    sign_out
    sign_in_as(users(:user_two))
  end

  def element_url(element, **options)
    universe_story_scene_scene_element_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: element, **options)
  end

  def element_move_url(element, direction, **options)
    move_universe_story_scene_scene_element_path(universe_slug: @universe.slug, story_id: @story,
      scene_id: @scene, id: element, direction: direction, **options)
  end

  test "creates a narration element at the end of the scene sequence" do
    assert_difference("SceneElement.count", 1) do
      post @elements_path, params: { scene_element: { kind: "narration", name: "The rain starts" } }, as: :json
    end

    created = @scene.scene_elements.order(:id).last
    assert_response :created
    assert_equal "The rain starts", created.name
    assert_equal SceneElement::NARRATION, created.kind
    assert_predicate created.body, :blank?
    assert_equal @scene.scene_elements.count - 1, created.position
    assert_equal @scene.scene_elements.reorder(:position, :id).pluck(:position),
      (0...@scene.scene_elements.count).to_a
  end

  test "creates a dialogue element with many speakers" do
    ids = @scene.universe.characters.pluck(:id)

    assert_difference("SceneElement.count", 1) do
      post @elements_path, params: {
        scene_element: { kind: "dialogue", name: "The kitchen argument", body: "You knew.", character_ids: ids }
      }, as: :json
    end

    created = @scene.scene_elements.order(:id).last
    assert_response :created
    assert_equal ids.sort, created.character_ids.sort
    assert_equal ids.sort, response.parsed_body["character_ids"].sort
  end

  test "the response carries the element the page will show again" do
    post @elements_path, params: { scene_element: { kind: "narration", name: "A beat" } }, as: :json

    assert_equal "A beat", response.parsed_body["name"]
    assert_equal "narration", response.parsed_body["kind"]
    assert_match %r{/elements/\d+\z}, response.parsed_body["url"]
  end

  test "an element cannot be given a position by a form" do
    post @elements_path, params: {
      scene_element: { kind: "narration", name: "First please", position: 0 }
    }, as: :json

    assert_response :created
    assert_equal @scene.scene_elements.count - 1, response.parsed_body["position"]
  end

  test "a dialogue without a speaker is a 422 the modal can render" do
    assert_no_difference("SceneElement.count") do
      post @elements_path, params: { scene_element: { kind: "dialogue", name: "Nobody" } }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "is required for a dialogue element" ], response.parsed_body["character_ids"]
  end

  test "a title is required and a kind outside the two known ones is refused" do
    post @elements_path, params: { scene_element: { kind: "narration", name: "" } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "can't be blank" ], response.parsed_body["name"]

    post @elements_path, params: { scene_element: { kind: "aside", name: "Monologue" } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "is not included in the list" ], response.parsed_body["kind"]
  end

  test "a speaker from another universe is a 422 rather than a cross-scope write" do
    outsider = universes(:universe_two).characters.create!(name: "Outsider")

    assert_no_difference("SceneElement.count") do
      post @elements_path, params: {
        scene_element: { kind: "dialogue", name: "Wrong speaker", character_ids: [ outsider.id ] }
      }, as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the scene's universe" ], response.parsed_body["character_ids"]
  end

  test "an unknown speaker id is a 422 rather than a foreign key error" do
    post @elements_path, params: {
      scene_element: { kind: "dialogue", name: "Ghost", character_ids: [ 0 ] }
    }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "must exist" ], response.parsed_body["character_ids"]
  end

  test "updates the title and content without moving the element" do
    element = scene_elements(:narration_one)
    original_position = element.position

    patch element_url(element), params: { scene_element: { name: "The hollow oak", body: "He lets go." } }, as: :json

    assert_response :success
    element.reload
    assert_equal [ "The hollow oak", "He lets go." ], [ element.name, element.body ]
    assert_equal original_position, element.position
  end

  test "updates the speakers of a dialogue" do
    element = scene_elements(:dialogue_one)

    patch element_url(element), params: {
      scene_element: { character_ids: [ @scene.universe.characters.first.id ] }
    }, as: :json

    assert_response :success
    assert_equal [ @scene.universe.characters.first.id ], element.reload.character_ids
  end

  test "an edit that does not mention speakers keeps them" do
    element = scene_elements(:dialogue_one)
    speaker_ids = element.character_ids

    patch element_url(element), params: { scene_element: { name: "The waltz, again" } }, as: :json

    assert_response :success
    assert_equal speaker_ids.sort, element.reload.character_ids.sort
  end

  test "narration cannot keep speakers and the explicit confirmation clears them" do
    element = scene_elements(:dialogue_one)

    patch element_url(element), params: { scene_element: { kind: "narration" } }, as: :json

    assert_response :unprocessable_content
    assert_equal [ "cannot be Narration while speakers are still assigned" ], response.parsed_body["kind"]
    assert_equal SceneElement::DIALOGUE, element.reload.kind

    patch element_url(element), params: {
      scene_element: { kind: "narration", remove_speakers: "1" }
    }, as: :json

    assert_response :success
    element.reload
    assert_equal SceneElement::NARRATION, element.kind
    assert_empty element.characters
  end

  test "moves an element up and down in its own sequence" do
    first, second = @scene.scene_elements.reorder(:position, :id).first(2)

    patch element_move_url(second, "up"), as: :json

    assert_response :success
    assert_equal [ second, first ], @scene.scene_elements.reorder(:position, :id).first(2)
    assert_equal [ 0, 1, 2, 3 ], @scene.scene_elements.reorder(:position, :id).pluck(:position)

    patch element_move_url(second, "down"), as: :json

    assert_response :success
    assert_equal [ first, second ], @scene.scene_elements.reorder(:position, :id).first(2)
  end

  test "moving past either end of the sequence is a no-op" do
    first = @scene.scene_elements.reorder(:position, :id).first
    last = @scene.scene_elements.reorder(:position, :id).last

    patch element_move_url(first, "up"), as: :json

    assert_response :success
    assert_equal 0, first.reload.position

    patch element_move_url(last, "down"), as: :json

    assert_response :success
    assert_equal 3, last.reload.position
    assert_equal [ 0, 1, 2, 3 ], @scene.scene_elements.reorder(:position, :id).pluck(:position)
  end

  test "a move needs a known direction" do
    element = scene_elements(:narration_one)

    patch element_move_url(element, "sideways"), as: :json

    assert_response :bad_request
    assert_equal 0, element.reload.position
  end

  test "destroying an element closes the gap and removes its speaker links" do
    element = scene_elements(:dialogue_one)

    assert_difference("SceneElement.count", -1) do
      delete element_url(element), as: :json
    end

    assert_response :no_content
    assert_equal [ 0, 1, 2 ], @scene.scene_elements.reorder(:position, :id).pluck(:position)
    assert_equal 2, @scene.universe.characters.count, "a shared character is never deleted with an element"
    assert_equal 0, ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM scene_element_speakers WHERE scene_element_id = #{element.id}"
    ).to_i
  end

  test "an html mutation is refused before anything is written" do
    assert_no_difference("SceneElement.count") do
      post @elements_path, params: { scene_element: { kind: "narration", name: "From a browser form" } }
    end
    assert_response :not_acceptable

    assert_no_difference("SceneElement.count") do
      patch element_url(scene_elements(:narration_one)), params: { scene_element: { name: "Renamed" } }
    end
    assert_response :not_acceptable

    assert_no_difference("SceneElement.count") do
      delete element_url(scene_elements(:narration_one))
    end
    assert_response :not_acceptable

    patch element_move_url(scene_elements(:narration_one), "down")
    assert_response :not_acceptable
  end

  test "guests are sent to sign in and read-only members are refused" do
    universe, story, scene = private_scene
    element = scene.scene_elements.create!(name: "Private element")
    sign_in_read_only_member(universe)

    assert_no_difference("SceneElement.count") do
      post universe_story_scene_scene_elements_url(universe_slug: universe.slug, story_id: story, scene_id: scene),
        params: { scene_element: { kind: "narration", name: "No" } }, as: :json
    end
    assert_response :forbidden

    patch universe_story_scene_scene_element_url(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: element), params: { scene_element: { name: "Renamed" } }, as: :json
    assert_response :forbidden

    patch move_universe_story_scene_scene_element_url(universe_slug: universe.slug, story_id: story,
      scene_id: scene, id: element, direction: "down"), as: :json
    assert_response :forbidden

    assert_no_difference("SceneElement.count") do
      delete universe_story_scene_scene_element_url(universe_slug: universe.slug, story_id: story,
        scene_id: scene, id: element), as: :json
    end
    assert_response :forbidden

    assert_equal "Private element", element.reload.name

    sign_out

    assert_no_difference("SceneElement.count") do
      post universe_story_scene_scene_elements_url(universe_slug: universe.slug, story_id: story, scene_id: scene),
        params: { scene_element: { kind: "narration", name: "Guest" } }, as: :json
    end
    assert_redirected_to new_session_url
  end

  test "an element of another universe is not found" do
    other_scene = stories(:story_two).scenes.create!(name: "Other universe scene")
    other_element = other_scene.scene_elements.create!(name: "Other element")

    patch element_url(other_element), params: { scene_element: { name: "Hijacked" } }, as: :json
    assert_response :not_found

    patch universe_story_scene_scene_element_url(universe_slug: universes(:universe_two).slug,
      story_id: stories(:story_two), scene_id: other_scene, id: scene_elements(:narration_one)),
      params: { scene_element: { name: "Hijacked" } }, as: :json
    assert_response :not_found

    assert_equal "The hollow tree", scene_elements(:narration_one).reload.name
    assert_equal "Other element", other_element.reload.name
  end

  test "the collection is not a read action because elements are read on scene details" do
    get @elements_path

    assert_response :not_found
  end

  test "an element cannot be managed through another scene, story, or universe" do
    element = scene_elements(:narration_one)
    other_scene = scenes(:scene_three)
    other_story = stories(:story_alt)

    patch universe_story_scene_scene_element_url(universe_slug: @universe.slug, story_id: @story,
      scene_id: other_scene, id: element), params: { scene_element: { name: "Hijacked" } }, as: :json
    assert_response :not_found

    patch universe_story_scene_scene_element_url(universe_slug: @universe.slug, story_id: other_story,
      scene_id: scenes(:scene_alt), id: element), params: { scene_element: { name: "Hijacked" } }, as: :json
    assert_response :not_found

    delete universe_story_scene_scene_element_url(universe_slug: @universe.slug, story_id: @story,
      scene_id: other_scene, id: element), as: :json
    assert_response :not_found

    assert_equal "The hollow tree", element.reload.name
  end
end
