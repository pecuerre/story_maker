require "test_helper"

class OwnershipTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_ownership_types_url(universe_slug: @universe.slug)
    assert_response :success
  end

  test "should create ownership_type as json" do
    assert_difference("OwnershipType.count") do
      post universe_ownership_types_url(universe_slug: @universe.slug),
        params: { ownership_type: { name: "Owns", description: "Has possession of" } },
        as: :json
    end

    assert_response :created
    assert_equal "Owns", response.parsed_body["name"]
  end
end
