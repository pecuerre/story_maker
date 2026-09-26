require "test_helper"

# The machine-readable facts a later analyzer will read. Epic 11 stores structure,
# not correctness, so what these tests pin down is the *shape* of that structure:
# several Scenes may depict one Event, `position` stays the narrative order, and
# neither the Event's timeline nor a Scene's in-world datetime may quietly become
# a second order.
#
# They are deliberately model-level and analyzer-oriented rather than about one
# page, because a page can only ever show one story at a time.
class SceneContinuityQueriesTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = stories(:story_one)
  end

  test "several scenes may depict one event and none of them is merged" do
    event = events(:event_one)
    first = scenes(:scene_one)
    # A second Scene, told later, depicting the same in-world fact: this is the
    # shape that lets one event be retold from a different context.
    second = @story.scenes.create!(name: "The same fact retold", position: 3, event: event)

    assert_equal [ first, second ].sort_by { |scene| [ scene.position, scene.id ] }, event.scenes.reorder(:position, :id)
    assert_equal 2, event.scenes.count
    # Neither Scene was rewritten to point somewhere else, and neither gained the
    # other's position.
    assert_equal event, first.reload.event
    assert_equal 3, second.position
    assert_not_equal first.position, second.position
  end

  test "narrative order is scene position even when in-world times say otherwise" do
    # `scene_three` is told last and happens between the other two; `scene_two` is
    # told second and carries no in-world time at all.
    scenes = @story.scenes.reorder(:position, :id).to_a
    in_world_order = scenes.select(&:datetime).sort_by(&:datetime)

    assert_equal [ 0, 1, 2 ], scenes.map(&:position)
    assert_equal [ "Scene one", "Scene two", "Scene three" ], scenes.map(&:name)
    # Sorting by datetime is a different list, which is exactly why nothing in the
    # model may use it as the story's order.
    assert_not_equal scenes.map(&:id), in_world_order.map(&:id)
    assert_operator scenes.first.datetime, :<, scenes.last.datetime
  end

  test "an event reference and a scene datetime stay independent values" do
    # Scene one carries both; scene three carries only a datetime. Selecting or
    # changing one must never write or validate against the other, so a scene may
    # have either, both, or neither.
    both = scenes(:scene_one)
    datetime_only = scenes(:scene_three)

    assert_predicate both.event, :present?
    assert_predicate both.datetime, :present?
    assert_nil datetime_only.event
    assert_predicate datetime_only.datetime, :present?
    assert_nil @story.scenes.create!(name: "Neither", position: 4).event
  end

  test "a world record can appear in many scenes of one story and in other stories" do
    item = items(:item_one)
    elsewhere = stories(:story_alt).scenes.create!(name: "Alt scene two", position: 1)
    item.scene_items.create!(scene: elsewhere, role: "still missing")

    # One record, three Scenes, two Stories: the shared-universe decision means
    # link rows, never copies, so continuity can be queried from either side.
    assert_equal 3, item.scene_items.count
    assert_equal [ "Alt scene two", "Scene one", "Scene three" ],
      item.scene_items.includes(:scene).map { |link| link.scene.name }.sort
    assert_equal @universe, item.universe
    assert_equal [ elsewhere.story, @story ], item.scene_items.includes(:scene)
      .map { |link| link.scene.story }.uniq.sort_by { |story| story.name }
  end

  test "an appearance query is bounded to one story so two stories never blend" do
    item = items(:item_one)
    stories(:story_alt).scenes.create!(name: "Alt scene two", position: 1).scene_items.create!(item: item)

    appearances = SceneAppearances.for(item, story: @story)

    assert_equal [ "Scene one", "Scene three" ], appearances.entries.map { |entry| entry.scene.name }
    assert appearances.entries.all? { |entry| entry.scene.story_id == @story.id }
  end

  test "every world link of a scene stays inside the scene's own universe" do
    # The application-level rule, stated once: SQLite foreign keys cannot prove a
    # shared scope, so every presence link carries its own check.
    scene = scenes(:scene_one)
    assert_equal [ @universe ], scene.scene_characters.includes(:character).map(&:universe).uniq
    assert_equal [ @universe ], scene.scene_items.includes(:item).map(&:universe).uniq
    assert_equal [ @universe ], scene.scene_locations.includes(:location).map(&:universe).uniq
    assert_equal [ @universe ], scene.scene_elements.map(&:universe).uniq
    assert_equal @universe, scene.universe
  end
end
