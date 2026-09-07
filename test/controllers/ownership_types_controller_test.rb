require "test_helper"

class OwnershipTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_ownership_types_url(story_slug: @story.slug)
    assert_response :success
  end

  test "should create ownership_type as json" do
    assert_difference("OwnershipType.count") do
      post story_ownership_types_url(story_slug: @story.slug),
        params: { ownership_type: { name: "Owns", description: "Has possession of" } },
        as: :json
    end

    assert_response :created
    assert_equal "Owns", response.parsed_body["name"]
  end
end
