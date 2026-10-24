require "test_helper"

class MapsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @location = locations(:location_one)
    sign_in_as(users(:user_one))
  end

  test "index shows the Location hierarchy and directional Route details" do
    child = @universe.locations.create!(name: "Nested room", parent: @location)
    route = routes(:route_one)

    get universe_map_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Map"
    assert_select "ul.map-location-tree > li a[href=?]",
      universe_location_path(universe_slug: @universe.slug, id: @location)
    assert_select "ul.map-location-children a[href=?]",
      universe_location_path(universe_slug: @universe.slug, id: child)
    assert_select "svg.map-diagram-svg[role=group]"
    assert_select ".map-diagram-node[href=?]",
      universe_location_path(universe_slug: @universe.slug, id: child)
    assert_select ".map-route-row", count: 1
    assert_select ".map-route-row .entity-title", text: route.display_string
    assert_select ".map-route-row a[href=?]",
      universe_location_path(universe_slug: @universe.slug, id: route.from_location)
    assert_select ".map-route-row a[href=?]",
      universe_location_path(universe_slug: @universe.slug, id: route.to_location)
    assert_select ".map-route-row a.details-link[href=?]",
      universe_route_path(universe_slug: @universe.slug, id: route)
    assert_select ".map-route-row .visually-hidden", text: "to"
    assert_select ".map-route-row a.details-link[aria-label=?]",
      "Details for #{route.display_string}"
    assert_select ".map-route-edge[data-route-id=?][marker-end='url(#map-route-arrow)']", route.id.to_s
    assert_select ".map-route-edge[data-from-location-id=?][data-to-location-id=?]",
      route.from_location_id.to_s, route.to_location_id.to_s
    assert_select "main form", count: 0
  end

  test "a guest can read the Map of a public universe" do
    sign_out

    get universe_map_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "h1", text: "Map"
    assert_select ".map-route-row", count: 1
  end

  test "private Map access follows read, write, and admin memberships" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private Map", slug: "private-map", private: true)
    private_universe.locations.create!(name: "Private place")
    sign_out

    get universe_map_url(universe_slug: private_universe.slug)
    assert_response :not_found

    sign_in_as(users(:user_two))
    get universe_map_url(universe_slug: private_universe.slug)
    assert_response :not_found
    sign_out

    %i[ read write admin ].each do |access_level|
      membership = UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: access_level)
      sign_in_as(users(:user_two))

      get universe_map_url(universe_slug: private_universe.slug)
      assert_response :success, "#{access_level} members can read the Map"

      sign_out
      membership.destroy!
    end

    sign_in_as(users(:user_one))
    get universe_map_url(universe_slug: private_universe.slug)
    assert_response :success
  end

  test "an empty Map gives readers useful copy and a Locations link" do
    @universe.locations.find_each(&:soft_delete)
    sign_out

    get universe_map_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "No locations to map yet"
    assert_select ".empty-description", text: "Locations in this universe will appear here once they have been added."
    assert_select ".empty-state a[href=?]",
      universe_locations_path(universe_slug: @universe.slug), text: "Browse locations"
    assert_select ".map-route-list", count: 0
  end

  test "a Map with Locations but no Routes explains where routes appear" do
    @universe.routes.find_each(&:soft_delete)

    get universe_map_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".map-location-tree li", minimum: 1
    assert_select "#map-routes-heading", text: "Routes"
    assert_select ".empty-title", text: "No routes yet"
    assert_select ".empty-state a[href=?]",
      universe_routes_path(universe_slug: @universe.slug), text: "Browse routes"
  end
end
