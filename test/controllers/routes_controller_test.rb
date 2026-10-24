require "test_helper"

class RoutesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @from = locations(:location_one)
    @to = locations(:location_two)
    sign_in_as(users(:user_one))
  end

  test "index lists routes and links the endpoint locations" do
    get universe_routes_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Routes"
    assert_select ".entity-row", text: /Road one/
    assert_select ".entity-row a[href=?]", universe_location_path(universe_slug: @universe.slug, id: @from)
    assert_select ".entity-row a[href=?]", universe_location_path(universe_slug: @universe.slug, id: @to)
  end

  test "creates a route with distance and duration" do
    assert_difference("Route.count") do
      post universe_routes_url(universe_slug: @universe.slug), params: {
        route: { name: "River road", from_location_id: @from.id, to_location_id: @to.id,
          distance: "8 miles", duration: "one hour" }
      }
    end

    assert_redirected_to universe_routes_url(universe_slug: @universe.slug)
    route = Route.order(:id).last
    assert_equal "8 miles", route.distance
    assert_equal "one hour", route.duration
  end

  test "refuses a location from another universe" do
    assert_no_difference("Route.count") do
      post universe_routes_url(universe_slug: @universe.slug), params: {
        route: { from_location_id: @from.id, to_location_id: locations(:location_three).id }
      }
    end

    assert_response :unprocessable_content
    assert_select ".alert-danger", text: /must belong to the route's universe/
  end

  test "updates and soft deletes a route" do
    route = routes(:route_one)

    patch universe_route_url(universe_slug: @universe.slug, id: route), params: {
      route: { distance: "13 miles" }
    }
    assert_response :see_other
    assert_equal "13 miles", route.reload.distance

    delete universe_route_url(universe_slug: @universe.slug, id: route)
    assert_response :see_other
    assert_predicate route.reload, :deleted?
  end

  test "a route from another universe is not found" do
    get universe_route_url(universe_slug: @universe.slug, id: Route.create!(
      universe: universes(:universe_two), from_location: locations(:location_three),
      to_location: locations(:location_three)
    ))

    assert_response :not_found
  end
end
