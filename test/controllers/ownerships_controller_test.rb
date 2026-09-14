require "test_helper"

class OwnershipsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @item = items(:item_one)
    @character = characters(:character_one)
    @ownership_type = OwnershipType.create!(universe: @universe, name: "Owns")
    sign_in_as(users(:user_one))
  end

  test "should get index with ownership options" do
    get universe_ownerships_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Ownerships"
    assert_includes response.body, @item.name
    assert_includes response.body, @ownership_type.name
  end

  test "should create ownership and redirect" do
    assert_difference("Ownership.count") do
      post universe_ownerships_url(universe_slug: @universe.slug), params: {
        ownership: {
          item_id: @item.id,
          character_id: @character.id,
          ownership_type_ids: [ @ownership_type.id ],
          description: "Held by the character"
        }
      }
    end

    assert_redirected_to universe_ownerships_url(universe_slug: @universe.slug)
    assert_equal "Held by the character", Ownership.order(:id).last.description
  end
end
