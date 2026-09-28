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

  test "a rejected taxonomy mutation answers 422 with the error hash the editor renders" do
    patch universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag),
      params: { character_tag: { name: "" } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "can't be blank" ], response.parsed_body["name"]
    assert_equal "Character tag one", @character_tag.reload.name
  end

  test "an association rejection is keyed on the association so the editor can find the field" do
    foreign_tag = character_tags(:character_tag_three)
    child = CharacterTag.create!(universe: @universe, name: "Nested tag", parent: @character_tag)

    patch universe_character_tag_url(universe_slug: @universe.slug, id: child),
      params: { character_tag: { name: child.name, parent_id: foreign_tag.id } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["parent"]
  end

  test "creates a grouping tag that is not taggable but is pinned to the menu" do
    assert_difference("CharacterTag.count") do
      post universe_character_tags_url(universe_slug: @universe.slug),
        params: { character_tag: { name: "Factions", taggable: false, show_in_menu: true } },
        as: :json
    end

    assert_response :created
    created = CharacterTag.find_by(name: "Factions")
    assert_equal false, response.parsed_body["taggable"]
    assert_equal true, response.parsed_body["show_in_menu"]
    assert_not created.taggable
    assert created.show_in_menu
  end

  test "updates taggable and show_in_menu" do
    patch universe_character_tag_url(universe_slug: @universe.slug, id: @character_tag),
      params: { character_tag: { name: @character_tag.name, taggable: false, show_in_menu: true } },
      as: :json

    assert_response :success
    assert_equal [ false, true ], @character_tag.reload.values_at(:taggable, :show_in_menu)
    assert_equal [ false, true ], response.parsed_body.values_at("taggable", "show_in_menu")
  end
end
