require "test_helper"

class CharacterTypesControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @character_type = character_types(:character_type_one)
    sign_in_as(users(:user_one))
  end

  test "should get index" do
    get story_character_types_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Character types"
    assert_includes response.body, @character_type.name
  end

  test "should create character type as json" do
    assert_difference("CharacterType.count") do
      post story_character_types_url(story_slug: @story.slug),
        params: { character_type: { name: "New character type", description: "A description" } },
        as: :json
    end

    assert_response :created
    assert_equal "New character type", response.parsed_body["name"]
    assert_equal "A description", CharacterType.order(:id).last.description
  end

  test "should update character type as json" do
    patch story_character_type_url(story_slug: @story.slug, id: @character_type),
      params: { character_type: { name: "Renamed", description: "Updated" } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated" ], @character_type.reload.values_at(:name, :description)
  end
end
