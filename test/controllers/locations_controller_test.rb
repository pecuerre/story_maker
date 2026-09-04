require "test_helper"

class LocationsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @location = locations(:location_one)
    @location_type = location_types(:location_type_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with location type options" do
    get story_locations_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Locations"
    assert_includes response.body, "Location type"
    assert_includes response.body, @location.name
  end

  test "should create location as json" do
    assert_difference("Location.count") do
      post story_locations_url(story_slug: @story.slug),
        params: { location: { name: "New location", description: "A description", location_type_id: @location_type.id } },
        as: :json
    end

    assert_response :created
    assert_equal @location_type.id, response.parsed_body["location_type_id"]
    assert_equal "A description", Location.order(:id).last.description
  end

  test "should update location details as json" do
    patch story_location_url(story_slug: @story.slug, id: @location),
      params: { location: { name: "Renamed", description: "Updated", location_type_id: @location_type.id } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated", @location_type.id ], @location.reload.values_at(:name, :description, :location_type_id)
  end
end
