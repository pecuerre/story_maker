require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @item = items(:item_one)
    @item_type = item_types(:item_type_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with item type options" do
    get story_items_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Items"
    assert_includes response.body, "Item type"
    assert_includes response.body, @item.name
  end

  test "should create item as json" do
    assert_difference("Item.count") do
      post story_items_url(story_slug: @story.slug),
        params: { item: { name: "New item", description: "A description", item_type_ids: [ @item_type.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @item_type.id ], response.parsed_body["item_type_ids"]
    assert_equal "A description", Item.order(:id).last.description
  end

  test "should update item details as json" do
    patch story_item_url(story_slug: @story.slug, id: @item),
      params: { item: { name: "Renamed", description: "Updated", item_type_ids: [ @item_type.id ] } },
      as: :json

    assert_response :success
    @item.reload
    assert_equal [ "Renamed", "Updated", [ @item_type.id ] ], [ @item.name, @item.description, @item.item_type_ids ]
  end
end
