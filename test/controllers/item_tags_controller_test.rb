require "test_helper"

class ItemTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @item_tag = item_tags(:item_tag_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_item_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Item tags"
    assert_includes response.body, @item_tag.name
  end

  test "should create item tag as json" do
    assert_difference("ItemTag.count") do
      post universe_item_tags_url(universe_slug: @universe.slug),
        params: { item_tag: { name: "New item tag", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New item tag", response.parsed_body["name"]
    assert_equal "A description", ItemTag.order(:id).last.description
  end

  test "should update item tag as json" do
    patch universe_item_tag_url(universe_slug: @universe.slug, id: @item_tag),
      params: { item_tag: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @item_tag.reload.values_at(:name, :description)
  end
end
