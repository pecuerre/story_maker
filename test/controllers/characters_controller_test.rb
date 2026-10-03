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

  # The row menu asks whether this reader may write the record once per row, and
  # every one of those answers reads the membership table. A signed-in reader who
  # is not the owner is the case that needs it at all, since a public universe
  # answers everybody else from its own column. What must not happen is the
  # lookup count following the row count.
  test "adding rows does not add write-access lookups" do
    sign_in_as(users(:user_two))

    with_two = count_queries(/FROM "universe_memberships"/) do
      get universe_characters_url(universe_slug: @universe.slug)
    end

    3.times { |index| @universe.characters.create!(name: "Listed #{index}") }

    with_five = count_queries(/FROM "universe_memberships"/) do
      get universe_characters_url(universe_slug: @universe.slug)
    end

    assert_response :success
    assert_equal with_two, with_five
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

  test "the character delete confirmation states that scenes and other records remain" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    # The character row is a JSON-only workspace, so its delete control is the modal
    # controller's button rather than a Turbo `button_to`. The mandatory consequence
    # copy is carried by that control and must not be weakened.
    assert_select "button[data-action='modal-form#destroy'][data-modal-form-url=?][data-modal-form-confirm=?]",
      universe_character_path(universe_slug: @universe.slug, id: @character),
      "Delete “#{@character.name}”? Its descendant characters, relations, ownerships, tag " \
      "assignments, and links to scenes will be permanently removed. Scenes and other universe " \
      "records will remain."
  end

  test "the character editor dropdown offers taggable tags only" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "select[name='character[character_tag_ids][]'] option", text: "Character tag one"
    assert_select "select[name='character[character_tag_ids][]'] option", text: "Character tag two", count: 0
  end

  test "a show_in_menu tag appears as a workspace tab linking to its details page" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav.content-tabs a[href=?]",
      universe_character_tag_path(universe_slug: @universe.slug, id: character_tags(:character_tag_one), from: "workspace"),
      text: "Character tag one"
  end
end
