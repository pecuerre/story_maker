require "test_helper"

class RelationTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_relation_tags_url(universe_slug: @universe.slug)
    assert_response :success
  end

  test "should create relation_tag as json" do
    assert_difference("RelationTag.count") do
      post universe_relation_tags_url(universe_slug: @universe.slug),
        params: { relation_tag: { name: "Knows", symmetric: false, inverse: "Known by" } },
        as: :json
    end

    assert_response :created
    assert_equal "Knows", response.parsed_body["name"]
    assert_equal false, response.parsed_body["symmetric"]
    assert_equal "Known by", response.parsed_body["inverse"]
  end

  test "rejects a non-symmetric relation without an inverse" do
    assert_no_difference("RelationTag.count") do
      post universe_relation_tags_url(universe_slug: @universe.slug),
        params: { relation_tag: { name: "Knows", symmetric: false } },
        as: :json
    end

    assert_response :unprocessable_content
  end

  test "should update relation_tag as json" do
    relation_tag = RelationTag.create!(universe: @universe, name: "Knows", symmetric: false, inverse: "Known by")

    patch universe_relation_tag_url(universe_slug: @universe.slug, id: relation_tag),
      params: { relation_tag: { symmetric: true, inverse: "" } },
      as: :json

    assert_response :success
    assert relation_tag.reload.symmetric
    assert_equal "", relation_tag.inverse
  end
end