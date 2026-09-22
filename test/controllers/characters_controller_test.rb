require "test_helper"

class CharactersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @character_tag = character_tags(:character_tag_two)
    sign_in_as(users(:user_one))
  end

  test "should get index with character tag options" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, "Characters"
    assert_includes response.body, "Character tag"
    assert_includes response.body, @character.name
  end

  test "should create character as json" do
    assert_difference("Character.count") do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "New character", description: "A description", character_tag_ids: [ @character_tag.id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @character_tag.id ], response.parsed_body["character_tag_ids"]
    assert_equal "A description", Character.order(:id).last.description
  end

  test "should update character details as json" do
    patch universe_character_url(universe_slug: @universe.slug, id: @character),
      params: { character: { name: "Renamed", description: "Updated", character_tag_ids: [ @character_tag.id ] } },
      as: :json

    assert_response :success
    @character.reload
    assert_equal [ "Renamed", "Updated", [ @character_tag.id ] ], [ @character.name, @character.description, @character.character_tag_ids ]
  end
end
