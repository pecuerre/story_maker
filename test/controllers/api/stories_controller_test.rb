require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::StoriesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's stories as json" do
    get api_universe_stories_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "Spin-off", "Story One" ],
      response.parsed_body.map { |story| story["name"] }.sort
  end

  test "index is empty for a universe without stories" do
    @universe.stories.destroy_all

    get api_universe_stories_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one story as json" do
    get api_universe_story_url(universe_slug: @universe.slug, id: stories(:story_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal stories(:story_one).id, body["id"]
    assert_equal stories(:story_one).name, body["name"]
    assert_equal "The main story of universe one", body["description"]
    assert_equal "story-one", body["slug"]
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_stories_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_stories_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_stories_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_stories_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end
end
