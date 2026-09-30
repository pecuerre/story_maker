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
    # The document title and the page heading are the same string, so the tab
    # reads "Location tags" exactly as the heading does.
    assert_select "h1", text: "Location tags"
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

  test "creates a grouping tag that is not taggable and pins it to the menu" do
    assert_difference("LocationTag.count") do
      post universe_location_tags_url(universe_slug: @universe.slug),
        params: { location_tag: { name: "Region", taggable: false, show_in_menu: true } },
        as: :json
    end

    assert_response :created
    created = LocationTag.find_by(name: "Region")
    assert_equal false, response.parsed_body["taggable"]
    assert_equal true, response.parsed_body["show_in_menu"]
    assert_not created.taggable
    assert created.show_in_menu
  end
end
