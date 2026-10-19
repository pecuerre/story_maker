require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::EventsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's events as json" do
    get api_universe_events_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "The beginning", "The end" ],
      response.parsed_body.map { |event| event["title"] }.sort
  end

  test "index is empty for a universe without events" do
    @universe.events.destroy_all

    get api_universe_events_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one event as json" do
    get api_universe_event_url(universe_slug: @universe.slug, id: events(:event_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal events(:event_one).id, body["id"]
    assert_equal events(:event_one).title, body["title"]
    assert_equal events(:event_one).start_datetime, body["start_datetime"]
    assert_equal events(:event_one).event_tag_ids, body["event_tag_ids"]
    assert_equal events(:event_one).position, body["position"]
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_events_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_events_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_events_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_events_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end
end
