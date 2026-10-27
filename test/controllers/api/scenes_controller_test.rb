require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::ScenesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @story = stories(:story_one)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the story's scenes as json" do
    get api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :success
    assert_equal [ "Scene one", "Scene three", "Scene two" ],
      response.parsed_body.map { |scene| scene["name"] }.sort
  end

  test "index is empty for a story without scenes" do
    @story.scenes.destroy_all

    get api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one scene as json" do
    get api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
      id: scenes(:scene_one)), headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal scenes(:scene_one).id, body["id"]
    assert_equal scenes(:scene_one).name, body["name"]
    assert_equal scenes(:scene_one).section_id, body["section_id"]
    assert_equal [ { "event_id" => events(:event_one).id, "role" => nil, "position" => 0 } ], body["events"]
    assert_nil body["pov_character_id"]
    assert_equal scenes(:scene_one).position, body["position"]
    assert_equal [ scene_tags(:scene_tag_one).id, scene_tags(:scene_tag_two).id ],
      body["scene_tag_ids"].sort
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_story_scenes_url(universe_slug: @other_universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
      headers: headers, as: :json

    assert_response :unauthorized
  end

  test "create creates a scene in its story as json" do
    assert_difference("Scene.count") do
      post api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        params: { scene: { name: "Api scene", description: "Via the API",
          section_id: sections(:section_one).id,
          pov_character_id: characters(:character_two).id,
          datetime: "2026-09-12 09:00:00" } },
        headers: headers, as: :json
    end

    assert_response :created
    body = response.parsed_body
    assert_equal "Api scene", body["name"]
    assert_equal "Via the API", body["description"]
    assert_equal sections(:section_one).id, body["section_id"]
    assert_empty body["events"]
    assert_equal characters(:character_two).id, body["pov_character_id"]
    assert_equal "api-scene", body["slug"]
    scene = Scene.find(body["id"])
    assert_equal @story.id, scene.story_id
    assert_equal characters(:character_two), scene.pov_character
    assert_equal scene.position, body["position"]
  end

  test "create rejects a point-of-view character from another universe" do
    assert_no_difference("Scene.count") do
      post api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        params: { scene: { name: "Cross-universe pov",
          pov_character_id: characters(:character_other_universe).id } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "create rejects a section from another story" do
    assert_no_difference("Scene.count") do
      post api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        params: { scene: { name: "Cross-story", section_id: sections(:section_alt).id } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "create rejects an unparseable datetime" do
    assert_no_difference("Scene.count") do
      post api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        params: { scene: { name: "Bad time", datetime: "not-a-time" } },
        headers: headers, as: :json
    end

    assert_response :unprocessable_content
  end

  test "update updates a scene as json" do
    patch api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
      id: scenes(:scene_two)),
      params: { scene: { name: "Renamed via api", description: "Via the API" } },
      headers: headers, as: :json

    assert_response :success
    assert_equal "Renamed via api", scenes(:scene_two).reload.name
    assert_equal "Via the API", scenes(:scene_two).reload.description
  end

  test "update rejects a section from another story" do
    patch api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
      id: scenes(:scene_two)),
      params: { scene: { section_id: sections(:section_alt).id } },
      headers: headers, as: :json

    assert_response :unprocessable_content
    assert_equal "Scene two", scenes(:scene_two).reload.name
  end

  test "destroy deletes a scene as json" do
    assert_difference("Scene.count", -1) do
      delete api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
        id: scenes(:scene_three)), headers: headers, as: :json
    end

    assert_response :no_content
  end

  test "move moves a scene up as json" do
    patch move_api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
      id: scenes(:scene_two), direction: "up"), headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 0, body["position"]
    assert_equal "Scene was moved.", body["notice"]
    assert_equal 0, scenes(:scene_two).reload.position
  end

  test "move at the first boundary stays put as json" do
    patch move_api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
      id: scenes(:scene_one), direction: "up"), headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal 0, body["position"]
    assert_equal "This scene is already first in the narrative order.", body["alert"]
  end

  test "move rejects an unknown direction" do
    patch move_api_universe_story_scene_url(universe_slug: @universe.slug, story_id: @story.id,
      id: scenes(:scene_one), direction: "sideways"), headers: headers, as: :json

    assert_response :bad_request
  end

  test "group groups a scene under a section as json" do
    patch group_api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id,
      scene_id: scenes(:scene_three).id, section_id: sections(:section_two).id),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal sections(:section_two).id, body["section_id"]
    assert_includes body["notice"], "Scene three"
    assert_equal sections(:section_two).id, scenes(:scene_three).reload.section_id
  end

  test "group ungroups a scene with a blank section as json" do
    patch group_api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id,
      scene_id: scenes(:scene_one).id, section_id: ""),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_nil body["section_id"]
    assert_includes body["notice"], "Scene one"
    assert_nil scenes(:scene_one).reload.section_id
  end

  test "group rejects a section from another story" do
    patch group_api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id,
      scene_id: scenes(:scene_three).id, section_id: sections(:section_alt).id),
      headers: headers, as: :json

    assert_response :not_found
  end

  test "a non-json scene mutation is refused before it writes" do
    assert_no_difference("Scene.count") do
      post api_universe_story_scenes_url(universe_slug: @universe.slug, story_id: @story.id),
        params: { scene: { name: "No json" } },
        headers: headers
    end

    assert_response :not_acceptable
  end
end
