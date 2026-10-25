require "test_helper"

# The API surface is authenticated by a bearer token rather than a session, so no
# `sign_in_as` is used here: every request carries `Authorization: Bearer …`.
class Api::LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @token = api_tokens(:token_one)   # issued for universe one only
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index lists the universe's locations as json" do
    get api_universe_locations_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_equal [ "Location one", "Location two" ],
      response.parsed_body.map { |location| location["name"] }.sort
  end

  test "index is empty for a universe without locations" do
    @universe.locations.destroy_all

    get api_universe_locations_url(universe_slug: @universe.slug), headers: headers, as: :json

    assert_response :success
    assert_empty response.parsed_body
  end

  test "show returns one location as json" do
    get api_universe_location_url(universe_slug: @universe.slug, id: locations(:location_one)),
      headers: headers, as: :json

    assert_response :success
    body = response.parsed_body
    assert_equal locations(:location_one).id, body["id"]
    assert_equal locations(:location_one).name, body["name"]
    assert_equal [ location_tags(:location_tag_one).id ], body["location_tag_ids"]
    assert_nil body["parent_id"]
    assert_equal locations(:location_one).position, body["position"]
    # Every profile answer is part of the record's JSON, including the ones this
    # fixture leaves blank, so an API consumer sees the same shape for every place.
    assert_equal "Gray light through a high window", body["sensory_sight"]
    assert_equal "The first place the story leaves", body["significance"]
    assert_nil body["sensory_sound"]
    assert_equal Location::PROFILE_FIELDS.map(&:to_s).sort, (body.keys & Location::PROFILE_FIELDS.map(&:to_s)).sort
  end

  test "a token issued for one universe is refused on another" do
    get api_universe_locations_url(universe_slug: @other_universe.slug), headers: headers, as: :json

    assert_response :not_found
  end

  test "a request without a bearer token is refused" do
    get api_universe_locations_url(universe_slug: @universe.slug), as: :json

    assert_response :unauthorized
  end

  test "an unknown bearer token is refused" do
    get api_universe_locations_url(universe_slug: @universe.slug),
      headers: { "Authorization" => "Bearer does-not-exist" }, as: :json

    assert_response :unauthorized
  end

  test "a revoked bearer token is refused" do
    api_tokens(:token_one).revoke!

    get api_universe_locations_url(universe_slug: @universe.slug),
      headers: headers, as: :json

    assert_response :unauthorized
  end
end
