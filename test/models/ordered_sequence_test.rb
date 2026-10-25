require "test_helper"

# `OrderedSequence` is the safety net for a positioned record that leaves or rejoins its
# sequence without going through `PositionedResourceOrder` — a direct `destroy!`, a direct
# `soft_delete`, a direct `restore`. `test/services/positioned_resource_order_test.rb` and
# the positioned controller tests hold the service path; these hold the model's own.
#
# The fixtures already fill each sequence and `position` defaults to 0, so every record
# this test creates is given the next slot explicitly and every assertion is about the
# contiguity of the whole collection as well as the order of these records within it.
class OrderedSequenceTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
    @other_story = stories(:story_alt)
    @universe = universes(:universe_one)
    @scene = scenes(:scene_one)
  end

  test "a direct destroy closes the gap in a flat scene sequence" do
    first = append_scene("First")
    second = append_scene("Second")
    third = append_scene("Third")

    second.destroy!

    assert_contiguous @story.scenes
    assert_equal [ first, third ], ordered(@story.scenes) & [ first, second, third ]
  end

  test "a direct destroy closes the gap in a scene element sequence" do
    first = append_element(@scene, "First")
    second = append_element(@scene, "Second")
    third = append_element(@scene, "Third")

    second.destroy!

    assert_contiguous @scene.scene_elements
    assert_equal [ first, third ], ordered(@scene.scene_elements) & [ first, second, third ]
  end

  # `SoftDeletable#soft_delete` is the path the application's own controllers call, so
  # before this the repair reached only a hard destroy the application never makes.
  test "a direct soft delete closes the gap in a flat sequence" do
    first = append_scene("First")
    second = append_scene("Second")
    third = append_scene("Third")

    second.soft_delete

    assert_contiguous @story.scenes
    assert_predicate second, :deleted?
    assert_equal [ first, third ], ordered(@story.scenes) & [ first, second, third ]
  end

  test "a direct soft delete closes the gap in a hierarchical sequence" do
    parent = @story.sections.create!(name: "Parent")
    first = append_section(parent, "First")
    second = append_section(parent, "Second")
    third = append_section(parent, "Third")

    second.soft_delete

    assert_contiguous parent.children
    assert_equal [ first, third ], ordered(parent.children) & [ first, second, third ]
  end

  test "a direct destroy closes the gap in a universe-scoped hierarchy" do
    first = append_location("First")
    second = append_location("Second")
    third = append_location("Third")

    second.destroy!

    assert_contiguous @universe.locations
    assert_equal [ first, third ], ordered(@universe.locations) & [ first, second, third ]
  end

  test "a restore puts a record back in its own slot rather than at the end" do
    first = append_scene("First")
    second = append_scene("Second")
    third = append_scene("Third")

    second.soft_delete
    second.restore

    assert_contiguous @story.scenes
    assert_equal [ first, second, third ], ordered(@story.scenes) & [ first, second, third ]
  end

  # The survivors were renumbered while the record was away, so the slot its own
  # `position` names may belong to somebody else now. The tie is broken by id, which is
  # the order the rest of the application reads these sequences in.
  test "a restore renumbers the sequence when the slot it left was taken" do
    first = append_scene("First")
    second = append_scene("Second")
    arrival = append_scene("Arrival")

    second.soft_delete
    arrival.update_column(:position, second.position)
    second.restore

    assert_contiguous @story.scenes
    assert_equal [ first, second, arrival ], ordered(@story.scenes) & [ first, second, arrival ]
  end

  test "a restore returns a record to its own sibling group inside a hierarchy" do
    parent = @story.sections.create!(name: "Parent")
    child = append_section(parent, "Child")
    sibling = append_section(parent, "Sibling")

    child.soft_delete
    child.restore

    assert_contiguous parent.children
    assert_equal [ child, sibling ], ordered(parent.children)
  end

  test "a repair touches only the sequence the record belongs to" do
    other_before = ordered(@other_story.scenes).map(&:id)
    mine = append_scene("Mine")
    removed = append_scene("Removed")

    removed.destroy!

    assert_equal other_before, ordered(@other_story.scenes).map(&:id)
    assert_contiguous @other_story.scenes
    assert_equal [ mine ], ordered(@story.scenes) & [ mine, removed ]
  end

  # A hierarchy's group is its parent, not its owner, so repairing one must not renumber a
  # group of the same story that has nothing to do with it.
  test "a hierarchy repair does not renumber a different sibling group" do
    parent = @story.sections.create!(name: "Parent")
    kept = append_section(parent, "Kept")
    removed = append_section(parent, "Removed")
    elsewhere = @story.sections.create!(name: "Elsewhere", position: 9)

    removed.destroy!

    assert_equal 0, kept.reload.position
    assert_equal 9, elsewhere.reload.position
  end

  # A Scene soft-deletes its Elements, and every cascaded delete repairs the sequence it
  # belongs to, so the cascade leaves nothing half-renumbered.
  test "a soft delete cascading through a subtree repairs every sequence it touched" do
    append_element(@scene, "Last")

    @scene.soft_delete

    assert_empty @scene.scene_elements.reload
    assert_empty @scene.scene_elements.with_deleted.where(deleted_at: nil)
  end

  # The declaration is what a flat model uses instead of a `parent_id`, so a renamed owner
  # association or a missing `has_many` would otherwise surface as a NoMethodError in
  # whichever callback ran first.
  test "a flat declaration names an association its owner actually has" do
    flat = positioned_models.reject { |model| model.column_names.include?("parent_id") }

    assert_equal [ Scene, SceneDialogueTurn, SceneElement ], flat

    flat.each do |model|
      owner = model.reflect_on_association(model.ordered_sequence_owner)

      assert_not_nil owner, "#{model} declares ordered_sequence_within #{model.ordered_sequence_owner}, which it does not belong to"
      assert_equal :belongs_to, owner.macro
      assert_not_nil owner.klass.reflect_on_association(model.model_name.collection),
        "#{owner.klass} has no #{model.model_name.collection} association for #{model}'s sequence"
    end
  end

  # The other direction of the same guard, and the reason the model list is walked from
  # the routed controllers: a positioned model that repairs nothing is the state this
  # concern exists to prevent, and a controller that declares an ordering nothing
  # maintains is the same state seen from the other side.
  test "every positioned model repairs the sequence its controller maintains" do
    assert_equal 17, positioned_models.size,
      "the number of positioned models is what this guard is checked against; a new one changes it"

    positioned_models.each do |model|
      assert_includes model.included_modules, OrderedSequence,
        "#{model} has a `position` column but does not include OrderedSequence, so a direct write to it " \
        "leaves a gap nothing closes"
    end
  end

  # `update_column` writes the column without running the model, so no callback can fire.
  # This is the boundary of the repair, asserted rather than assumed.
  test "a direct column write is not repaired" do
    append_scene("First")
    removed = append_scene("Removed")
    append_scene("Last")

    removed.update_column(:deleted_at, Time.current)

    assert_not_contiguous @story.scenes
  end

  private

    def append_scene(name)
      @story.scenes.create!(name: name, position: @story.scenes.count)
    end

    def append_element(scene, name)
      scene.scene_elements.create!(name: name, position: scene.scene_elements.count)
    end

    # `parent.children.create!` cannot supply the story the record needs, so a child is
    # built through the story and pointed at its parent.
    def append_section(parent, name)
      @story.sections.create!(name: name, parent: parent, position: parent.children.count)
    end

    def append_location(name)
      @universe.locations.create!(name: name, position: @universe.locations.count)
    end

    def ordered(relation)
      relation.reorder(:position, :id).to_a
    end

    # A live sequence is exactly `0..n-1`. A gap shows as a length that does not match the
    # positions, a duplicate as a repeated number, and both at once as neither.
    def assert_contiguous(relation)
      positions = ordered(relation).map(&:position)

      assert_equal (0...positions.length).to_a, positions
    end

    def assert_not_contiguous(relation)
      positions = ordered(relation).map(&:position)

      assert_not_equal (0...positions.length).to_a, positions
    end

    # Walked from the routed controllers rather than from `ApplicationRecord.descendants`,
    # which holds only the models this process happened to load — two of the fifteen are
    # invisible to it until something references them.
    def positioned_models
      routed_controllers.select { |controller| controller.include?(MaintainsSiblingPositions) }
        .map { |controller| controller.new.send(:sibling_position_resource_name).to_s.classify.constantize }
        .uniq
        .sort_by(&:name)
    end

    def routed_controllers
      Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq.filter_map do |name|
        "#{name}_controller".camelize.safe_constantize
      end
    end
end
