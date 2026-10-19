require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::EventTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's event tags as json" do
    get api_universe_event_tags_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "Event tag one", "Event tag two" ],
      response.parsed_body.map { |tag| tag["name"] }.sort
  end

  test "index is empty for a universe without event tags" do
    @universe.event_tags.destroy_all

    get api_universe_event_tags_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one event tag as json" do
    get api_universe_event_tag_url(universe_slug: @universe.slug, id: event_tags(:event_tag_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal event_tags(:event_tag_one).id, body["id"]
    assert_equal event_tags(:event_tag_one).name, body["name"]
    assert_equal event_tags(:event_tag_one).taggable, body["taggable"]
    assert_equal event_tags(:event_tag_one).slug, body["slug"]
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_event_tags_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_event_tags_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_event_tags_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_event_tags_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end
end
