require "test_helper"

class ItemsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @item = items(:item_one)
    @item_tag = item_tags(:item_tag_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with item tag options" do
    get universe_items_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Items"
    assert_includes response.body, "Item tag"
    assert_includes response.body, @item.name
  end

  test "should create item as json" do
    assert_difference("Item.count") do
      post universe_items_url(universe_slug: @universe.slug),
        params: { item: { name: "New item", description: "A description", item_tag_ids: [ @item_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @item_tag.id ], response.parsed_body["item_tag_ids"]
    assert_equal "A description", Item.order(:id).last.description
  end

  test "should update item details as json" do
    patch universe_item_url(universe_slug: @universe.slug, id: @item),
      params: { item: { name: "Renamed", description: "Updated", item_tag_ids: [ @item_tag.id ] } },
      as: :json

    assert_response :success
    @item.reload
    assert_equal [ "Renamed", "Updated", [ @item_tag.id ] ], [ @item.name, @item.description, @item.item_tag_ids ]
  end
end
