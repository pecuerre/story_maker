require "test_helper"

# `SceneAppearances` is the reverse of the Scene workspace tabs, and the analyzer
# entry point for continuity work: it must report every Scene a shared record
# appears in, say why, and never confuse narrative order with in-world chronology
# or a Scene with the Event it depicts.
class SceneAppearancesTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  def appearances_for(record, story: @story)
    SceneAppearances.for(record, story: story)
  end

  def scene_names(record, story: @story)
    appearances_for(record, story: story).entries.map { |entry| entry.scene.name }
  end

  test "a character's stored links and derived speakers are one appearance per scene" do
    # `character_one` is a stored participant of `scene_one` and also speaks in
    # its `dialogue_one`, so the two sources must not become two appearances.
    appearances = appearances_for(characters(:character_one))

    assert_equal [ "Scene one" ], appearances.entries.map { |entry| entry.scene.name }
    entry = appearances.entries.first
    assert_predicate entry, :linked?
    assert_predicate entry, :speaks?
    assert_not_predicate entry, :depicted?
    assert_equal "setting", entry.role
    assert_equal [ "Michael teaches the waltz" ], entry.speaking_elements
  end

  test "a character who only speaks is still an appearance, with no stored link" do
    outsider = @universe.characters.create!(name: "Passer-by")
    scene = @story.scenes.create!(name: "Street")
    scene.scene_elements.create!(name: "Passing", kind: "dialogue", characters: [ outsider ])

    appearances = appearances_for(outsider)

    assert_equal 1, appearances.count
    entry = appearances.entries.first
    assert_not_predicate entry, :linked?
    assert_predicate entry, :speaks?
    assert_nil entry.role
  end

  test "a character with no role is linked and not merely absent" do
    appearances = appearances_for(characters(:character_two))

    entry = appearances.entries.find { |candidate| candidate.scene == scenes(:scene_one) }
    assert_predicate entry, :linked?
    assert_nil entry.role
  end

  test "an item or a location appears only through a stored link" do
    assert_equal [ "Scene one", "Scene three" ], scene_names(items(:item_one))
    assert_equal [ "Scene one", "Scene three" ], scene_names(locations(:location_one))
    # Neither record derives a second source, so the link is the whole fact.
    appearances = appearances_for(locations(:location_one))
    assert_equal [ false, false ], appearances.entries.map(&:speaks?)
    assert_equal [ false, false ], appearances.entries.map(&:depicted?)
  end

  test "an event lists every scene that depicts it, in narrative order" do
    # `event_one` is the Scene's optional shared in-world fact, and the reference
    # is not a presence link, so it carries no role.
    appearances = appearances_for(events(:event_one))

    assert_equal [ "Scene one" ], appearances.entries.map { |entry| entry.scene.name }
    entry = appearances.entries.first
    assert_predicate entry, :depicted?
    assert_not_predicate entry, :linked?
    assert_nil entry.role
  end

  test "appearances are ordered by narrative position, not by in-world time" do
    # `scene_three` is told last but happens first, and it is ungrouped: neither
    # the datetime nor the section may influence the order of this section.
    item = items(:item_one)

    positions = appearances_for(item).entries.map { |entry| entry.scene.position }
    assert_equal positions.sort, positions
    assert_equal [ scenes(:scene_one).position, scenes(:scene_three).position ], positions
  end

  test "a scene created later in the same story is an appearance in narrative order" do
    # The controllers maintain contiguous positions; a directly created record is
    # given one explicitly so the ordering assertion is about this query.
    later = @story.scenes.create!(name: "Same story, later", position: 3)
    items(:item_one).scene_items.create!(scene: later, role: "again")

    assert_equal [ "Scene one", "Scene three", "Same story, later" ], scene_names(items(:item_one))
    assert_not_includes scene_names(items(:item_one)), "Alt scene"
    assert_equal later.position, appearances_for(items(:item_one)).entries.last.scene.position
  end

  test "without a story there is nothing to report rather than another story's scenes" do
    assert_empty appearances_for(items(:item_one), story: nil).entries
    assert_not appearances_for(items(:item_one), story: nil).any?
    assert_equal 0, appearances_for(items(:item_one), story: nil).count
  end

  test "a record from another universe can never be linked here, and so never appears" do
    outsider = universes(:universe_two).items.create!(name: "Outsider")

    # The presence link refuses the cross-universe reference, so the reverse query
    # has nothing to leak rather than merely refusing to show it.
    assert_not outsider.scene_items.create(scene: @story.scenes.create!(name: "Borrowed")).persisted?
    assert_not appearances_for(outsider).any?
  end

  test "an unsaved record has no appearances rather than raising" do
    assert_empty SceneAppearances.for(nil, story: @story).entries
    assert_empty SceneAppearances.for(Item.new, story: @story).entries
  end

  # The section backs a list, so a record appearing once and a record appearing in
  # every Scene must cost the same. These count the queries the object itself
  # issues, not the page's, so an unrelated navigation change cannot make them lie.
  test "the query count is fixed per record type, not per appearance" do
    appearances_query_counts = lambda do |record|
      count_queries { appearances_for(record).entries }
    end

    # A dedicated item, so the only links are the ones this test creates.
    item = @universe.items.create!(name: "Counted prop")
    scenes = @story.scenes.to_a
    scenes.each { |scene| scene.scene_items.create!(item: item) }
    # One query for the stored links and one for the Scene rows, whatever the
    # number of appearances.
    assert_equal scenes.size, appearances_for(item).count
    assert_equal 2, appearances_query_counts.call(item)
    item.scene_items.where(scene: scenes.first).delete_all
    assert_equal 2, appearances_query_counts.call(item),
      "the query count must not grow with the number of appearances"

    # A Character adds the derived-speaker query; an Event has no presence link at
    # all, so it needs one fewer.
    assert_equal 3, appearances_query_counts.call(characters(:character_one))
    assert_equal 2, appearances_query_counts.call(events(:event_one))
  end

  private
    def count_queries(&block)
      count = 0
      subscriber = ActiveSupport::Notifications.subscribe("sql.active_record") do |*, payload|
        count += 1 unless payload[:name] == "SCHEMA"
      end
      block.call
      count
    ensure
      ActiveSupport::Notifications.unsubscribe(subscriber) if subscriber
    end
end
