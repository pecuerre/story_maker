require "test_helper"

# Every standard element and every element tag now has its own details page.
# These tests cover the shared contract once: the page renders for every access
# level, it is scoped to its universe/story, a record from another scope is a
# 404, and a private universe stays invisible to non-members.
class RecordDetailsTest < ActionDispatch::IntegrationTest
  ELEMENT_PAGES = {
    "character" => { path: :universe_character_path, fixture: :characters, record: :character_one },
    "location" => { path: :universe_location_path, fixture: :locations, record: :location_one },
    "item" => { path: :universe_item_path, fixture: :items, record: :item_one },
    "event" => { path: :universe_event_path, fixture: :events, record: :event_one }
  }.freeze

  ELEMENT_TAG_PAGES = {
    "character tag" => { path: :universe_character_tag_path, fixture: :character_tags, record: :character_tag_one },
    "location tag" => { path: :universe_location_tag_path, fixture: :location_tags, record: :location_tag_one },
    "item tag" => { path: :universe_item_tag_path, fixture: :item_tags, record: :item_tag_one },
    "event tag" => { path: :universe_event_tag_path, fixture: :event_tags, record: :event_tag_one }
  }.freeze

  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @story = stories(:story_one)
    @other_story = stories(:story_alt)
  end

  test "every universe-scoped element renders its own details page" do
    sign_in_as(users(:user_one))

    ELEMENT_PAGES.each do |label, page|
      record = page_record(page)
      get send(page[:path], universe_slug: @universe.slug, id: record)

      assert_response :success
      assert_select "h1", text: record.try(:display_string) || record.name
      assert_select ".detail-facts .detail-fact", minimum: 2
      assert_includes response.body, label
    end
  end

  test "every universe-scoped element tag lists the records carrying it" do
    sign_in_as(users(:user_one))

    ELEMENT_TAG_PAGES.each do |label, page|
      tag = page_record(page)
      get send(page[:path], universe_slug: @universe.slug, id: tag)

      assert_response :success
      assert_select "h1", text: tag.name
      assert_includes response.body, label
      assert_select ".detail-section", minimum: 1

      tag.tagged_records.each do |record|
        element_path = page[:path].to_s.sub(/_tag_path\z/, "_path")

        assert_select "a[href=?]", send(element_path, universe_slug: @universe.slug, id: record),
          text: record.try(:display_string) || record.name
      end
    end
  end

  test "an element tag with no assigned records still renders its empty section" do
    tag = event_tags(:event_tag_one)

    sign_in_as(users(:user_one))
    get universe_event_tag_path(universe_slug: @universe.slug, id: tag)

    assert_response :success
    assert_select ".detail-section h2", text: "Events with this tag"
    assert_select ".empty-state", text: /Tags are optional/
  end

  test "a relation and an ownership render their endpoints" do
    character_one = characters(:character_one)
    character_two = characters(:character_two)
    item = items(:item_one)
    relation = Relation.create!(universe: @universe, character1: character_one, character2: character_two)
    ownership = Ownership.create!(universe: @universe, character: character_one, item: item)

    sign_in_as(users(:user_one))

    get universe_relation_path(universe_slug: @universe.slug, id: relation)
    assert_response :success
    assert_select "h1", text: "Character one → Character two"
    assert_select "a[href=?]", universe_character_path(universe_slug: @universe.slug, id: character_one)

    get universe_ownership_path(universe_slug: @universe.slug, id: ownership)
    assert_response :success
    assert_select "h1", text: "Character one owns Item one"
    assert_select "a[href=?]", universe_item_path(universe_slug: @universe.slug, id: item)
  end

  test "a section details page lists the scenes grouped under it" do
    sign_in_as(users(:user_one))

    get universe_story_section_path(universe_slug: @universe.slug, story_id: @story, id: sections(:section_one))

    assert_response :success
    assert_select "h1", text: "Section one"
    assert_select ".detail-section h2", text: "Scenes in this section"
    assert_select "a[href=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one))
  end

  test "a story-scoped tag lists its records and a section tag lists sections" do
    sign_in_as(users(:user_one))

    get universe_story_section_tag_path(universe_slug: @universe.slug, story_id: @story, id: section_tags(:section_tag_one))
    assert_response :success
    assert_select "a[href=?]",
      universe_story_section_path(universe_slug: @universe.slug, story_id: @story, id: sections(:section_one))

    get universe_story_scene_tag_path(universe_slug: @universe.slug, story_id: @story, id: scene_tags(:scene_tag_one))
    assert_response :success
    assert_select ".detail-section h2", text: "Scenes with this tag"
    assert_select "a[href=?]",
      universe_story_scene_path(universe_slug: @universe.slug, story_id: @story, id: scenes(:scene_one))
  end

  test "every details page is a guest-readable action on a public universe" do
    ELEMENT_PAGES.each_value do |page|
      get send(page[:path], universe_slug: @universe.slug, id: page_record(page))

      assert_response :success
    end

    ELEMENT_TAG_PAGES.each_value do |page|
      get send(page[:path], universe_slug: @universe.slug, id: page_record(page))

      assert_response :success
    end
  end

  # A render smoke test for the pages the typed tests above do not build records
  # for, so a template error or a missing local can never reach a page unnoticed.
  test "every remaining details page renders" do
    character = characters(:character_one)
    character_two = characters(:character_two)
    item = items(:item_one)
    relation = Relation.create!(universe: @universe, character1: character, character2: character_two)
    ownership = Ownership.create!(universe: @universe, character: character, item: item)
    relation_tag = RelationTag.create!(universe: @universe, name: "Relation detail tag")
    ownership_tag = OwnershipTag.create!(universe: @universe, name: "Ownership detail tag")

    sign_in_as(users(:user_one))

    {
      universe_relation_path: relation,
      universe_ownership_path: ownership,
      universe_relation_tag_path: relation_tag,
      universe_ownership_tag_path: ownership_tag
    }.each do |path_helper, record|
      get send(path_helper, universe_slug: @universe.slug, id: record)

      assert_response :success
      assert_select "h1", text: (record.try(:display_string) || record.name)
    end

    {
      universe_story_section_path: sections(:section_two),
      universe_story_section_tag_path: section_tags(:section_tag_two),
      universe_story_scene_tag_path: scene_tags(:scene_tag_two)
    }.each do |path_helper, record|
      get send(path_helper, universe_slug: @universe.slug, story_id: @story, id: record)

      assert_response :success
      assert_select "h1", text: record.name
    end
  end

  test "a tag page with no assigned records states it instead of showing an empty box" do
    relation_tag = RelationTag.create!(universe: @universe, name: "Unused relation tag")

    sign_in_as(users(:user_one))
    get universe_relation_tag_path(universe_slug: @universe.slug, id: relation_tag)

    assert_response :success
    assert_select ".detail-section h2", text: "Relations with this tag"
    assert_select ".empty-state", text: /No relations carry this tag/
  end

  test "a details page is a read-only destination for a guest and a read member" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private read page universe", slug: "private-read-page", private: true)
    private_character = Character.create!(universe: private_universe, name: "Private read page character")
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)

    get universe_character_path(universe_slug: @universe.slug, id: characters(:character_one))
    assert_response :success
    assert_select "main form", count: 0
    assert_select ".row-actions", count: 0

    sign_in_as(users(:user_two))
    get universe_character_path(universe_slug: private_universe.slug, id: private_character)
    assert_response :success
    assert_select "main form", count: 0
    assert_select ".row-actions", count: 0
    assert_select "a", text: "All characters"
  end

  test "a record from another universe or story is a 404" do
    sign_in_as(users(:user_one))

    get universe_character_path(universe_slug: @other_universe.slug, id: characters(:character_one))
    assert_response :not_found

    get universe_story_section_path(universe_slug: @universe.slug, story_id: @other_story, id: sections(:section_one))
    assert_response :not_found

    get universe_story_section_tag_path(universe_slug: @universe.slug, story_id: @other_story, id: section_tags(:section_tag_one))
    assert_response :not_found
  end

  test "a private universe's details page is a 404 for a non-member and readable for a member" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private details universe", slug: "private-details", private: true)
    character = Character.create!(universe: private_universe, name: "Private character")
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)

    sign_in_as(users(:user_two))
    get universe_character_path(universe_slug: private_universe.slug, id: character)
    assert_response :success
    sign_out

    get universe_character_path(universe_slug: private_universe.slug, id: character)
    assert_response :not_found
  end

  test "a read member without write access is refused on a details-page mutation" do
    private_universe = Universe.create!(owner: users(:user_one), name: "Private read details universe", slug: "private-read-details", private: true)
    character = Character.create!(universe: private_universe, name: "Read only character")
    UniverseMembership.create!(universe: private_universe, user: users(:user_two), access_level: :read)

    sign_in_as(users(:user_two))
    patch universe_character_path(universe_slug: private_universe.slug, id: character),
      params: { character: { name: "Renamed" } },
      as: :json

    assert_response :forbidden
    assert_equal "Read only character", character.reload.name
  end

  private
    def page_record(page)
      public_send(page.fetch(:fixture), page.fetch(:record))
    end
end
