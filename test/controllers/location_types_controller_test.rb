require "test_helper"

class LocationTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @location_type = location_types(:location_type_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_location_types_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Location types"
    assert_includes response.body, @location_type.name
  end

  test "should create location type as json" do
    assert_difference("LocationType.count") do
      post story_location_types_url(story_slug: @story.slug),
        params: { location_type: { name: "New location type", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New location type", response.parsed_body["name"]
    assert_equal "A description", LocationType.order(:id).last.description
  end

  test "should update location type as json" do
    patch story_location_type_url(story_slug: @story.slug, id: @location_type),
      params: { location_type: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @location_type.reload.values_at(:name, :description)
  end
end
