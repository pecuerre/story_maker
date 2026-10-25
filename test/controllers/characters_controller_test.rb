require "test_helper"

class CharactersControllerTest < ActionDispatch::IntegrationTest
  setup do
    @universe = universes(:universe_one)
    @character = characters(:character_one)
    @character_tag = character_tags(:character_tag_two)
    sign_in_as(users(:user_one))
  end

  # The names in the order the list rendered them, so a filter or a sort
  # assertion says which characters survived it without depending on row markup.
  def listed_character_names
    css_select(".entity-list .entity-title").map { |title| title.text.squish }
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

  # The filter, the sort, and the three ways this list can be empty. The value
  # object is covered in `CharacterFilterTest`; what a request can show and this
  # cannot is the page around it — the canonical URL, the two empty states, and
  # what a filter does to the reader's own pending rows.
  test "index renders a search area that narrows, orders, and stays in the URL" do
    @character.update!(at_a_glance: "The keeper of the gate")
    @universe.characters.create!(name: "A spare")

    get universe_characters_url(universe_slug: @universe.slug, q: "keeper", sort: "created")

    assert_response :success
    assert_select "form[action=?][method=?]", universe_characters_path(universe_slug: @universe.slug), "get" do
      assert_select "input[name=q][value=?]", "keeper"
      assert_select "select[name=sort] option[selected][value=?]", "created"
    end
    assert_equal [ "Character one" ], listed_character_names
    assert_select ".character-filter", text: /Showing 1 character of 4 characters/
  end

  test "index orders the whole list by the reader's choice" do
    characters(:character_one).update!(created_at: Time.utc(2026, 1, 1))
    characters(:character_two).update!(created_at: Time.utc(2026, 3, 1))
    characters(:character_three).update!(created_at: Time.utc(2026, 2, 1))

    get universe_characters_url(universe_slug: @universe.slug, sort: "created")

    assert_response :success
    assert_equal [ "Character two", "Character three", "Character one" ], listed_character_names
  end

  test "index filters by character tag, including a grouping tag the editor cannot assign" do
    assert_not @character_tag.taggable?, "this is the case the editor's picker cannot reach"

    get universe_characters_url(universe_slug: @universe.slug,
      character_tag_id: @character_tag.id)

    assert_response :success
    assert_equal [ "Character two" ], listed_character_names,
      "the grouping tag narrows to the one character that carries it"
    assert_select "select[name=character_tag_id] option[selected][value=?]", @character_tag.id
  end

  test "index offers a nested tag by its full path rather than its leaf name" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_select "select[name=character_tag_id] option", text: "Character tag one / Character tag child"
  end

  test "index redirects a form submission to the canonical filter query" do
    get universe_characters_url(universe_slug: @universe.slug, q: "keeper", character_tag_id: "", sort: "")

    assert_redirected_to universe_characters_url(universe_slug: @universe.slug, q: "keeper")
  end

  test "index reports a filter value it could not use instead of showing an empty list" do
    get universe_characters_url(universe_slug: @universe.slug,
      character_tag_id: character_tags(:character_tag_three).id)

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not a character tag of this universe/
    assert_equal [ "Character one", "Character three", "Character two" ], listed_character_names
  end

  test "index reports an order this list does not offer and falls back to the default" do
    get universe_characters_url(universe_slug: @universe.slug, sort: "password")

    assert_response :success
    assert_select ".flash-alert, .alert", text: /not one this list offers/
    assert_select "select[name=sort] option[selected][value=?]", CharacterFilter::DEFAULT_SORT
    assert_equal [ "Character one", "Character three", "Character two" ], listed_character_names
  end

  test "index does not redirect a filter value it had to drop" do
    get universe_characters_url(universe_slug: @universe.slug,
      character_tag_id: character_tags(:character_tag_three).id, q: "keeper")

    assert_response :success
  end

  test "index separates a filtered empty result from a universe without characters" do
    @universe.characters.create!(name: "A real character")

    get universe_characters_url(universe_slug: @universe.slug, q: "no such character")

    assert_response :success
    assert_select ".empty-title", text: "No characters match these filters"
    assert_select ".empty-description", text: /Universe one has 4 characters, but none of them match/
    assert_select ".empty-state .badge", text: /Search: .no such character./
    assert_select ".empty-state a", text: "Clear filters"
    # The empty result is the only way back, so the search area does not repeat it.
    assert_select ".character-filter a", text: "Clear filters", count: 0
    # The universe is not empty, so the message must not offer to add the first
    # character beside it. The page header's own Add action is a different thing
    # and stays.
    assert_select ".empty-state a", text: /Add character/, count: 0
  end

  test "index still offers to add the first character to an empty universe" do
    @universe.characters.destroy_all

    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select ".empty-title", text: "No characters yet"
    assert_select ".page-actions button", text: "Add character"
  end

  test "a sort alone never empties the list and never changes the empty-database message" do
    @universe.characters.destroy_all

    get universe_characters_url(universe_slug: @universe.slug, sort: "created")

    assert_response :success
    assert_select ".empty-title", { text: "No characters yet" },
      "an order cannot select a record, so it cannot produce an empty result"
  end

  test "a guest can filter and sees no mutation control" do
    sign_out

    get universe_characters_url(universe_slug: @universe.slug, q: "character one")

    assert_response :success
    assert_equal [ "Character one" ], listed_character_names
    assert_select "form[data-controller=modal-form]", count: 0
    assert_select "button[data-action='modal-form#open']", count: 0
    # The search area is reading, so it renders for every access level.
    assert_select ".character-filter input[name=q]", minimum: 1
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

  test "index rows show relation and ownership counts" do
    # character_one has relation_one (as character1) and ownership_one
    # character_two has relation_one (as character2)
    # character_three has neither
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    # Two characters have exactly one relation each
    assert_select ".record-count", text: "(1 relation)", count: 2
    # One character has exactly one ownership
    assert_select ".record-count", text: "(1 ownership)", count: 1
  end

  test "index does not issue per-row queries for relation and ownership counts" do
    3.times { |index| @universe.characters.create!(name: "Listed #{index}") }

    with_fewer = count_queries(/FROM "(relations|ownerships)"/) do
      get universe_characters_url(universe_slug: @universe.slug)
    end

    3.times { |index| @universe.characters.create!(name: "More #{index}") }

    with_more = count_queries(/FROM "(relations|ownerships)"/) do
      get universe_characters_url(universe_slug: @universe.slug)
    end

    assert_response :success
    # Eager loading keeps the relations/ownerships query count flat as rows grow.
    assert_equal with_fewer, with_more
  end

  test "should create character as json" do
    assert_difference("Character.count") do
      post universe_characters_url(universe_slug: @universe.slug),
        params: { character: { name: "New character", at_a_glance: "A description", character_tag_ids: [ @character_tag.id ], faction_ids: [ factions(:faction_two).id ] } },
        as: :json
    end

    assert_response :created
    assert_equal [ @character_tag.id ], response.parsed_body["character_tag_ids"]
    assert_equal "A description", Character.order(:id).last.at_a_glance
    assert_equal [ factions(:faction_two).id ], response.parsed_body["faction_ids"]
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
      params: { character: { name: "Renamed", at_a_glance: "Updated", character_tag_ids: [ @character_tag.id ] } },
      as: :json

    assert_response :success
    @character.reload
    assert_equal [ "Renamed", "Updated", [ @character_tag.id ] ], [ @character.name, @character.at_a_glance, @character.character_tag_ids ]
  end

  test "the character delete confirmation states that scenes and other records remain" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    # The character row is a JSON-only workspace, so its delete control is the modal
    # controller's button rather than a Turbo `button_to`. The mandatory consequence
    # copy is carried by that control and must not be weakened.
    assert_select "button[data-action='modal-form#destroy'][data-modal-form-url=?][data-modal-form-confirm=?]",
      universe_character_path(universe_slug: @universe.slug, id: @character),
      "Delete “#{@character.name}”? Its descendant characters, relations, ownerships, knowledge " \
      "records, tag assignments, and links to scenes will be permanently removed. Scenes, factions, " \
      "and other universe records will remain."
  end

  test "the character editor dropdown offers taggable tags only" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "select[name='character[character_tag_ids][]'] option", text: "Character tag one"
    assert_select "select[name='character[character_tag_ids][]'] option", text: "Character tag two", count: 0
  end

  test "the character editor offers optional universe factions" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "select[name='character[faction_ids][]'] option", text: "Faction one"
    assert_select "select[name='character[faction_ids][]'] option", text: "Other universe faction", count: 0
  end

  test "a character cannot be assigned a faction from another universe" do
    post universe_characters_url(universe_slug: @universe.slug),
      params: { character: { name: "Mis-scoped faction", faction_ids: [ factions(:faction_other_universe).id ] } },
      as: :json

    assert_response :unprocessable_content
    assert_equal [ "must belong to the same universe" ], response.parsed_body["factions"]
  end

  test "character details show profile, faction, and knowledge records" do
    @character.update!(at_a_glance: "A quick summary", wants: "The key")
    knowledge = character_knowledges(:knowledge_one)

    get universe_character_url(universe_slug: @universe.slug, id: @character)

    assert_response :success
    assert_includes response.body, "A quick summary"
    assert_includes response.body, "The key"
    assert_includes response.body, "Faction one"
    assert_select "#character-knowledge-heading", text: "What this character knows"
    assert_select "article", text: /#{Regexp.escape(knowledge.what_learned)}/
  end

  test "a show_in_menu tag appears as a workspace tab linking to its details page" do
    get universe_characters_url(universe_slug: @universe.slug)

    assert_response :success
    assert_select "nav.content-tabs a[href=?]",
      universe_character_tag_path(universe_slug: @universe.slug, id: character_tags(:character_tag_one), from: "workspace"),
      text: "Character tag one"
  end
end
