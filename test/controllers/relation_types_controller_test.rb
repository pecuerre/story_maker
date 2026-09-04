require "test_helper"

class RelationTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_relation_types_url(story_slug: @story.slug)
    assert_response :success
  end

  test "should create relation_type as json" do
    assert_difference("RelationType.count") do
      post story_relation_types_url(story_slug: @story.slug),
        params: { relation_type: { name: "Knows", symmetric: false, inverse: "Known by" } },
        as: :json
    end

    assert_response :created
    assert_equal "Knows", response.parsed_body["name"]
    assert_equal false, response.parsed_body["symmetric"]
    assert_equal "Known by", response.parsed_body["inverse"]
  end

  test "rejects a non-symmetric relation without an inverse" do
    assert_no_difference("RelationType.count") do
      post story_relation_types_url(story_slug: @story.slug),
        params: { relation_type: { name: "Knows", symmetric: false } },
        as: :json
    end

    assert_response :unprocessable_content
  end

  test "should update relation_type as json" do
    relation_type = RelationType.create!(story: @story, name: "Knows", symmetric: false, inverse: "Known by")

    patch story_relation_type_url(story_slug: @story.slug, id: relation_type),
      params: { relation_type: { symmetric: true, inverse: "" } },
      as: :json

    assert_response :success
    assert relation_type.reload.symmetric
    assert_equal "", relation_type.inverse
  end
end