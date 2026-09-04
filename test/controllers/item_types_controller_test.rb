require "test_helper"

class ItemTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @item_type = item_types(:item_type_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_item_types_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Item types"
    assert_includes response.body, @item_type.name
  end

  test "should create item type as json" do
    assert_difference("ItemType.count") do
      post story_item_types_url(story_slug: @story.slug),
        params: { item_type: { name: "New item type", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New item type", response.parsed_body["name"]
    assert_equal "A description", ItemType.order(:id).last.description
  end

  test "should update item type as json" do
    patch story_item_type_url(story_slug: @story.slug, id: @item_type),
      params: { item_type: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @item_type.reload.values_at(:name, :description)
  end
end
