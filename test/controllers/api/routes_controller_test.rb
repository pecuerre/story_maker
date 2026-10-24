require "test_helper"

class Api::RoutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @token = api_tokens(:token_one)
    @bearer = "alpha-api-token-one"
  end

  def headers
    { "Authorization" => "Bearer #{@bearer}" }
  end

  test "index and show return routes as json" do
    get api_universe_routes_url(universe_slug: @universe.slug), headers: headers, as: :json
    assert_response :success
    assert_equal [ "road-one" ], response.parsed_body.map { |route| route["slug"] }

    get api_universe_route_url(universe_slug: @universe.slug, id: routes(:route_one)),
      headers: headers, as: :json
    assert_response :success
    assert_equal "12 miles", response.parsed_body["distance"]
  end

  test "creates and updates routes as json" do
    assert_difference("Route.count") do
      post api_universe_routes_url(universe_slug: @universe.slug),
        params: { route: { from_location_id: locations(:location_one).id,
          to_location_id: locations(:location_two).id, distance: "5 miles" } },
        headers: headers, as: :json
    end
    assert_response :created
    id = response.parsed_body.fetch("id")

    patch api_universe_route_url(universe_slug: @universe.slug, id: id),
      params: { route: { duration: "half a day" } }, headers: headers, as: :json
    assert_response :success
    assert_equal "half a day", Route.find(id).duration
  end

  test "cross-universe endpoint and non-json mutations are refused" do
    assert_no_difference("Route.count") do
      post api_universe_routes_url(universe_slug: @universe.slug),
        params: { route: { from_location_id: locations(:location_one).id,
          to_location_id: locations(:location_three).id } }, headers: headers, as: :json
    end
    assert_response :unprocessable_content

    assert_no_difference("Route.count") do
      post api_universe_routes_url(universe_slug: @universe.slug),
        params: { route: { from_location_id: locations(:location_one).id,
          to_location_id: locations(:location_two).id } }, headers: headers
    end
    assert_response :not_acceptable
  end
end
