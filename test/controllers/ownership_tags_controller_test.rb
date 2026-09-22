require "test_helper"

class OwnershipTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_ownership_tags_url(universe_slug: @universe.slug)
    assert_response :success
  end

  test "should create ownership_tag as json" do
    assert_difference("OwnershipTag.count") do
      post universe_ownership_tags_url(universe_slug: @universe.slug),
        params: { ownership_tag: { name: "Owns", description: "Has possession of" } },
        as: :json
    end

    assert_response :created
    assert_equal "Owns", response.parsed_body["name"]
  end
end
