require "test_helper"

class CharacterTagsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character_tag = character_tags(:character_tag_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get universe_character_tags_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Character Tags"
    assert_includes response.body, @character_tag.name
  end

  test "should create character tag as json" do
    assert_difference("CharacterTag.count") do
      post universe_character_tags_url(universe_slug: @universe.slug),
        params: { character_tag: { name: "New character tag", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New character tag", response.parsed_body["name"]
    assert_equal "A description", CharacterTag.order(:id).last.description
  end

  test "should update character tag as json" do
    patch universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag),
      params: { character_tag: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @character_tag.reload.values_at(:name, :description)
  end
end
