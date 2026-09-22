require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @location = locations(:location_one)
    @location_tag = location_tags(:location_tag_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with location tag options" do
    get universe_locations_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Locations"
    assert_includes response.body, "Location tag"
    assert_includes response.body, @location.name
  end

  test "should create location as json" do
    assert_difference("Location.count") do
      post universe_locations_url(universe_slug: @universe.slug),
        params: { location: { name: "New location", description: "A description", location_tag_ids: [ @location_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @location_tag.id ], response.parsed_body["location_tag_ids"]
    assert_equal "A description", Location.order(:id).last.description
  end

  test "should update location details as json" do
    patch universe_location_url(universe_slug: @universe.slug, id: @location),
      params: { location: { name: "Renamed", description: "Updated", location_tag_ids: [ @location_tag.id ] } },
      as: :json

    assert_response :success
    @location.reload
    assert_equal [ "Renamed", "Updated", [ @location_tag.id ] ], [ @location.name, @location.description, @location.location_tag_ids ]
  end
end
