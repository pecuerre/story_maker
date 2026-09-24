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
    assert_select ".page-header h1", text: "Characters"
    assert_select ".entity-row", minimum: 1 do
      assert_select ".row-actions .dropdown-menu", text: /Edit/
      assert_select "button[data-action='modal-form#open'][data-modal-form-url=?]",
        universe_character_path(universe_slug: @universe.slug, id: @character)
    end
    assert_select ".page-actions button", text: "Add character"
    assert_select "nav.content-tabs a.active[aria-current=page][href=?]",
      universe_characters_path(universe_slug: @universe.slug)
    assert_select "nav.content-tabs a[href=?]",
      universe_relations_path(universe_slug: @universe.slug), text: "Relations"
  end

  test "index does not render a corrupt cross-universe tag join" do
    foreign_tag = character_tags(:character_tag_three)
    ActiveRecord::Base.connection.execute(<<~SQL.squish)
      INSERT INTO characters_character_tags (character_id, character_tag_id)
      VALUES (#{@character.id}, #{foreign_tag.id})
    SQL

    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_includes response.body, @character.name
    assert_not_includes response.body, foreign_tag.name
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

  test "should create a character without tags" do
    assert_difference("Character.count") do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Untagged character" } },
        as: :json
    end

    assert_response :created
    assert_empty response.parsed_body["character_tag_ids"]
    assert_empty Character.order(:id).last.character_tags
  end

  test "should reject character tags from another universe" do
    foreign_tag = character_tags(:character_tag_three)
    join_count = -> { ActiveRecord::Base.connection.select_value("SELECT COUNT(*) FROM characters_character_tags") }

    assert_no_difference([ "Character.count", join_count ]) do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "Mis-scoped character", character_tag_ids: [ foreign_tag.id ] } },
        as: :json
    end

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["character_tags"]
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
