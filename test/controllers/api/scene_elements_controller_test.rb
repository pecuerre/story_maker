require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::SceneElementsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the scene's elements as json" do
    get api_universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id), headers: headers, as: :json

    assert_response :success
    assert_equal [ "Interlude", "Michael teaches the waltz", "The adults argue", "The hollow tree" ],
      response.parsed_body.map { |element| element["name"] }.sort
  end

  test "index is empty for a scene without elements" do
    @scene.scene_elements.destroy_all

    get api_universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "index orders elements by position" do
    get api_universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id), headers: headers, as: :json

    assert_response :success
    names = response.parsed_body.map { |element| element["name"] }
    assert_equal names, names.sort_by { |_| response.parsed_body.find { |e| e["name"] == _ }["position"] }
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_story_scene_scene_elements_url(universe_slug: @other_universe.slug,
      story_id: @story.id, scene_id: @scene.id), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_story_scene_scene_elements_url(universe_slug: @universe.slug,
      story_id: @story.id, scene_id: @scene.id), headers: headers, as: :json

    assert_response :unauthorized
  end
end
