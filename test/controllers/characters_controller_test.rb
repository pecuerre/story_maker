require "test_helper"

class CharactersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @story = stories(:story_one)
    @character = characters(:character_one)
    @character_type = character_types(:character_type_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with character type options" do
    get story_characters_url(story_slug: @story.slug)

    assert_response :success
    assert_includes response.body, "Characters"
    assert_includes response.body, "Character type"
    assert_includes response.body, @character.name
  end

  test "should create character as json" do
    assert_difference("Character.count") do
      post story_characters_url(story_slug: @story.slug),
        params: { character: { name: "New character", description: "A description", character_type_id: @character_type.id } },
        as: :json
    end

    assert_response :created
    assert_equal @character_type.id, response.parsed_body["character_type_id"]
    assert_equal "A description", Character.order(:id).last.description
  end

  test "should update character details as json" do
    patch story_character_url(story_slug: @story.slug, id: @character),
      params: { character: { name: "Renamed", description: "Updated", character_type_id: @character_type.id } },
      as: :json

    assert_response :success
    assert_equal [ "Renamed", "Updated", @character_type.id ], @character.reload.values_at(:name, :description, :character_type_id)
  end
end
