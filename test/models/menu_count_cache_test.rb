require "test_helper"

class MenuCountCacheTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @original_cache = Rails.cache
    Rails.cache = ActiveSupport::Cache::MemoryStore.new
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  teardown do
    Rails.cache = @original_cache
  end

  test "caches all universe menu counts together" do
    expected_counts = {
      characters: 2,
      relations: 0,
      locations: 2,
      events: 2,
      items: 2,
      ownerships: 0
    }

    assert_equal expected_counts, @universe.menu_counts
    assert_no_queries { assert_equal expected_counts, @universe.menu_counts }
  end

  test "caches a story's section count" do
    assert_equal 2, @story.menu_section_count
    assert_no_queries { assert_equal 2, @story.menu_section_count }
  end

  test "a story's scene count uses its own cache entry" do
    @story.menu_section_count

    assert_equal 3, @story.menu_scene_count
    assert_no_queries { assert_equal 3, @story.menu_scene_count }

    section_key = MenuCountCache.key(Story::SECTION_MENU_COUNT_SCOPE, @story.id)
    scene_key = MenuCountCache.key(Story::SCENE_MENU_COUNT_SCOPE, @story.id)
    assert_not_equal section_key, scene_key
    assert Rails.cache.exist?(section_key)
    assert Rails.cache.exist?(scene_key)
  end

  test "a story scene count refreshes when scenes are created or destroyed" do
    original_count = @story.menu_scene_count
    scene = @story.scenes.create!(name: "Cached scene")

    assert_equal original_count + 1, @story.menu_scene_count
    assert_equal 2, @story.menu_section_count, "creating a scene must not change the section count"

    scene.destroy!
    assert_equal original_count, @story.menu_scene_count
  end

  test "universe menu counts refresh after every counted model is created or destroyed" do
    counted_records = {
      characters: -> { Character.create!(universe: @universe, name: "Cached character") },
      relations: -> {
        Relation.create!(
          universe: @universe,
          character1: characters(:character_one),
          character2: characters(:character_two)
        )
      },
      locations: -> { Location.create!(universe: @universe, name: "Cached location") },
      events: -> { Event.create!(universe: @universe, title: "Cached event") },
      items: -> { Item.create!(universe: @universe, name: "Cached item") },
      ownerships: -> {
        Ownership.create!(
          universe: @universe,
          character: characters(:character_one),
          item: items(:item_one)
        )
      }
    }

    counted_records.each do |count_name, build_record|
      original_count = @universe.menu_counts.fetch(count_name)
      record = build_record.call

      assert_equal original_count + 1, @universe.menu_counts.fetch(count_name),
        "#{record.class} creation did not invalidate #{count_name}"

      record.destroy!
      assert_equal original_count, @universe.menu_counts.fetch(count_name),
        "#{record.class} destruction did not invalidate #{count_name}"
    end
  end

  test "a story section count refreshes when sections are created or destroyed" do
    original_count = @story.menu_section_count
    section = @story.sections.create!(name: "Cached section")

    assert_equal original_count + 1, @story.menu_section_count

    section.destroy!
    assert_equal original_count, @story.menu_section_count
  end

  test "dependent destroys invalidate every affected universe count" do
    character = characters(:character_one)
    Relation.create!(
      universe: @universe,
      character1: character,
      character2: characters(:character_two)
    )
    Ownership.create!(
      universe: @universe,
      character: character,
      item: items(:item_one)
    )
    @universe.menu_counts

    character.destroy!

    assert_equal(
      { characters: 1, relations: 0, ownerships: 0 },
      @universe.menu_counts.slice(:characters, :relations, :ownerships)
    )
  end

  test "normal updates keep a valid universe count cached" do
    @universe.menu_counts

    characters(:character_one).update!(name: "Renamed character")

    assert_no_queries { assert_equal 2, @universe.menu_counts.fetch(:characters) }
  end

  test "moving a counted record invalidates both universe counts" do
    other_universe = universes(:universe_two)
    location = Location.create!(universe: @universe, name: "Moving location")
    original_count = @universe.menu_counts.fetch(:locations)
    other_original_count = other_universe.menu_counts.fetch(:locations)

    location.update!(universe: other_universe)

    assert_equal original_count - 1, @universe.menu_counts.fetch(:locations)
    assert_equal other_original_count + 1, other_universe.menu_counts.fetch(:locations)
  end

  test "multiple scope moves in one transaction invalidate every universe count" do
    second_universe = universes(:universe_two)
    third_universe = Universe.create!(owner: users(:user_one), name: "Third universe")
    location = Location.create!(universe: @universe, name: "Multimove location")
    original_counts = [ @universe, second_universe, third_universe ].index_with do |universe|
      universe.menu_counts.fetch(:locations)
    end

    location.transaction do
      location.update!(universe: second_universe)
      location.update!(universe: third_universe)
    end

    assert_equal original_counts.fetch(@universe) - 1, @universe.menu_counts.fetch(:locations)
    assert_not Rails.cache.exist?(MenuCountCache.key(:universe, second_universe.id))
    assert_equal original_counts.fetch(second_universe), second_universe.menu_counts.fetch(:locations)
    assert_equal original_counts.fetch(third_universe) + 1, third_universe.menu_counts.fetch(:locations)
  end

  test "a savepoint rollback does not discard outer transaction invalidations" do
    second_universe = universes(:universe_two)
    third_universe = Universe.create!(owner: users(:user_one), name: "Savepoint universe")
    location = Location.create!(universe: @universe, name: "Savepoint location")
    original_counts = [ @universe, second_universe, third_universe ].index_with do |universe|
      universe.menu_counts.fetch(:locations)
    end

    location.transaction do
      location.update!(universe: second_universe)

      location.transaction(requires_new: true) do
        location.update!(universe: third_universe)
        raise ActiveRecord::Rollback
      end
    end

    assert_equal original_counts.fetch(@universe) - 1, @universe.menu_counts.fetch(:locations)
    assert_not Rails.cache.exist?(MenuCountCache.key(:universe, second_universe.id))
    assert_equal original_counts.fetch(second_universe) + 1, second_universe.menu_counts.fetch(:locations)
    assert_equal original_counts.fetch(third_universe), third_universe.menu_counts.fetch(:locations)
  end

  test "moving a section invalidates both story counts" do
    other_story = stories(:story_alt)
    section = @story.sections.create!(name: "Moving section")
    original_count = @story.menu_section_count
    other_original_count = other_story.menu_section_count

    section.update!(story: other_story)

    assert_equal original_count - 1, @story.menu_section_count
    assert_equal other_original_count + 1, other_story.menu_section_count
  end

  test "cache misses inside rolled back writes are not retained" do
    key = MenuCountCache.key(:universe, @universe.id)
    original_count = @universe.characters.count

    Character.transaction do
      Character.create!(universe: @universe, name: "Rolled back character")

      assert_equal original_count + 1, @universe.menu_counts.fetch(:characters)
      assert_not Rails.cache.exist?(key)
      raise ActiveRecord::Rollback
    end

    assert_equal original_count, @universe.menu_counts.fetch(:characters)
    assert Rails.cache.exist?(key)
  end

  test "rolled back writes leave a valid cached count in place" do
    original_count = @universe.menu_counts.fetch(:characters)

    Character.transaction do
      Character.create!(universe: @universe, name: "Rolled back character")
      raise ActiveRecord::Rollback
    end

    assert_no_queries do
      assert_equal original_count, @universe.menu_counts.fetch(:characters)
    end
  end

  test "destroying empty owners removes their cached counts" do
    universe = Universe.create!(owner: users(:user_one), name: "Empty cache owner")
    story = universe.stories.create!(name: "Empty cache owner")
    universe_key = MenuCountCache.key(:universe, universe.id)
    section_key = MenuCountCache.key(Story::SECTION_MENU_COUNT_SCOPE, story.id)
    scene_key = MenuCountCache.key(Story::SCENE_MENU_COUNT_SCOPE, story.id)

    universe.menu_counts
    story.menu_section_count
    story.menu_scene_count
    assert Rails.cache.exist?(universe_key)
    assert Rails.cache.exist?(section_key)
    assert Rails.cache.exist?(scene_key)

    story.destroy!
    assert_not Rails.cache.exist?(section_key)
    assert_not Rails.cache.exist?(scene_key)

    universe.destroy!
    assert_not Rails.cache.exist?(universe_key)
  end
end
