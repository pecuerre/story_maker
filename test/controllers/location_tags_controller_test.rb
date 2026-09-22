require "test_helper"

class LocationTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @location_tag = location_tags(:location_tag_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_location_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Location tags"
    assert_includes response.body, @location_tag.name
  end

  test "should create location tag as json" do
    assert_difference("LocationTag.count") do
      post universe_location_tags_url(universe_slug: @universe.slug),
        params: { location_tag: { name: "New location tag", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New location tag", response.parsed_body["name"]
    assert_equal "A description", LocationTag.order(:id).last.description
  end

  test "should update location tag as json" do
    patch universe_location_tag_url(universe_slug: @universe.slug, id: @location_tag),
      params: { location_tag: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @location_tag.reload.values_at(:name, :description)
  end
end
