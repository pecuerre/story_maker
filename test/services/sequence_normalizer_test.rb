require "test_helper"

# The repair path for a write that bypassed the model entirely: raw SQL, `update_column`,
# `delete_all`, or a `create!` naming its own `position`. `test/models/ordered_sequence_test.rb`
# holds what the model repairs on its own; this holds the command that walks whole tables,
# because that is the only thing standing between such a write and a sequence that stays broken.
#
# The fixtures are not contiguous — two Sections share position 0 — which is the honest
# starting state for a command whose job is to fix exactly that, so assertions here are
# about a whole sequence being `0..n-1` rather than about one record's position.
class SequenceNormalizerTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
    @story = stories(:story_one)
    @scene = scenes(:scene_one)
  end

  test "it renumbers a sequence a raw write left with a gap" do
    first = append_scene("First")
    second = append_scene("Second")
    third = append_scene("Third")
    second.update_column(:deleted_at, Time.current)

    summary = SequenceNormalizer.new.call

    assert summary.changed?
    assert_contiguous @story.scenes
    assert_equal [ first, third ], ordered(@story.scenes) & [ first, second, third ]
  end

  # A gap check alone would miss these, and a duplicate position is what an import that
  # assigns its own numbers produces. The two records are asserted against each other
  # rather than against 0 and 1, because the command renumbers the whole group and the
  # fixtures already hold the slots before them.
  test "it renumbers duplicates" do
    first = append_scene("First")
    second = append_scene("Second")
    first.update_column(:position, 5)
    second.update_column(:position, 5)

    SequenceNormalizer.new.call

    assert_contiguous @story.scenes
    assert_equal [ first, second ], ordered(@story.scenes) & [ first, second ]
    assert_equal 1, second.reload.position - first.reload.position
  end

  # A hierarchy's group is its parent, so a child group is numbered from zero whatever
  # the story's own top-level sections are doing.
  test "it renumbers a hierarchy per sibling group rather than per story" do
    parent = @story.sections.create!(name: "Parent")
    first = append_section(parent, "First")
    second = append_section(parent, "Second")

    first.update_column(:position, 4)
    SequenceNormalizer.new.call

    assert_contiguous parent.children
    # The displaced record sorted to the end, which is what `(position, id)` says it
    # should do: a repair fixes the numbering, it does not restore an order nobody stored.
    assert_equal [ second, first ], ordered(parent.children)
    assert_equal [ 0, 1 ], ordered(parent.children).map(&:position)
  end

  test "a group that is already contiguous is left exactly as it is" do
    parent = @story.sections.create!(name: "Untouched parent")
    first = append_section(parent, "Kept")
    second = append_section(parent, "Also kept")
    before = [ first.position, second.position ]
    output = StringIO.new

    SequenceNormalizer.new(output: output).call

    assert_equal before, [ first.reload.position, second.reload.position ]
    assert_not_includes output.string, "Kept"
  end

  # The check is what makes the command something other than a step somebody has to
  # remember, so "writes nothing" is the property it has to earn rather than assume.
  test "the check reports a gap without writing anything" do
    scene = @story.scenes.create!(name: "Displaced", position: 7)
    before = @story.scenes.reload.map { |s| [ s.id, s.position ] }
    output = StringIO.new

    summary = SequenceNormalizer.new(output: output).check

    assert summary.changed?
    assert_includes output.string, 'would move Scene "Displaced"'
    assert_includes output.string, "position 7 -> "
    assert_equal before, @story.scenes.reload.map { |s| [ s.id, s.position ] }
    assert_equal 7, scene.reload.position
  end

  test "the check says which sequence is broken, not only that something is" do
    append_scene("First")
    append_scene("Second")
    @story.scenes.last.update_column(:position, 9)
    output = StringIO.new

    SequenceNormalizer.new(output: output).check

    assert_includes output.string, @story.name
  end

  test "the check reports nothing once the sequences are contiguous" do
    SequenceNormalizer.new.call
    output = StringIO.new

    summary = SequenceNormalizer.new(output: output).check

    assert_not summary.changed?
    assert_equal "every sequence is contiguous", summary.to_s
    assert_empty output.string
  end

  # The check and the repair have to be looking at the same set. If they ever diverged,
  # the check would go green while the repair still had work to do, which is worse than
  # not having a check at all.
  test "the check reports exactly what the repair would move" do
    append_scene("First")
    append_scene("Second")
    @story.scenes.last.update_column(:position, 9)
    checked = StringIO.new
    repaired = StringIO.new

    checked_summary = SequenceNormalizer.new(output: checked).check
    repaired_summary = SequenceNormalizer.new(output: repaired).call

    assert_equal repaired_summary.moves.map { |move| [ move.model.name, move.record.id, move.from, move.to ] },
      checked_summary.moves.map { |move| [ move.model.name, move.record.id, move.from, move.to ] }
  end

  test "the check leaves another universe's gap unreported when asked for one" do
    @other_universe.locations.create!(name: "Elsewhere", position: 4)
    output = StringIO.new

    SequenceNormalizer.new(output: output).check_for_universe(@universe)

    assert_not_includes output.string, "Elsewhere"
  end

  # Running it twice is the property a person relying on it needs: the second run has
  # nothing left to do, and says so rather than reporting the first run's work again.
  test "a second run finds nothing left to do" do
    SequenceNormalizer.new.call
    output = StringIO.new

    summary = SequenceNormalizer.new(output: output).call

    assert_not summary.changed?
    assert_equal "every sequence is already contiguous", summary.to_s
    assert_empty output.string
  end

  # A command whose whole value is being able to see what it did: an ordering a reader
  # cannot check is not a report.
  test "it reports each record it moves, with the sequence and both positions" do
    scene = @story.scenes.create!(name: "Displaced", position: 7)
    output = StringIO.new

    SequenceNormalizer.new(output: output).call

    assert_includes output.string, "Displaced"
    assert_includes output.string, "position 7 -> "
    assert_includes output.string, @story.name
    assert_equal ordered(@story.scenes).index { |s| s.id == scene.id }, scene.reload.position
  end

  # A record already where it belongs is not a move, and reporting it would bury the
  # ones that are.
  test "it does not report a record that was already in place" do
    SequenceNormalizer.new.call
    output = StringIO.new

    SequenceNormalizer.new(output: output).call

    assert_empty output.string
  end

  test "it leaves another universe alone when asked for one" do
    elsewhere = @other_universe.locations.create!(name: "Elsewhere", position: 4)
    mine = @universe.locations.create!(name: "Mine", position: 4)

    SequenceNormalizer.new.call_for_universe(@universe)

    assert_contiguous @universe.locations
    assert_not_equal 4, mine.reload.position
    assert_equal 4, elsewhere.reload.position,
      "a universe that was not asked for keeps every position it had"
  end

  test "it renumbers a scene's own elements when that universe is normalized" do
    first = append_element(@scene, "First")
    second = append_element(@scene, "Second")
    first.update_column(:position, 6)

    SequenceNormalizer.new.call_for_universe(@universe)

    assert_contiguous @scene.scene_elements
    assert_equal [ second, first ], ordered(@scene.scene_elements) & [ first, second ]
  end

  test "it renumbers turns per Element when that universe is normalized" do
    element = scene_elements(:dialogue_one)
    last = element.scene_dialogue_turns.create!(speaker: characters(:character_one), body: "Last", position: 8)
    other_element = @scene.scene_elements.create!(name: "Another dialogue", kind: "dialogue",
      characters: [ characters(:character_two) ])
    other_turn = other_element.scene_dialogue_turns.create!(speaker: characters(:character_two),
      body: "First here", position: 5)
    output = StringIO.new

    SequenceNormalizer.new(output: output).call_for_universe(@universe)

    assert_equal [ 0, 1, 2 ], element.scene_dialogue_turns.order(:position, :id).pluck(:position)
    assert_equal [ 0 ], other_element.scene_dialogue_turns.pluck(:position)
    assert_includes output.string, "in Element"
    assert_equal 2, last.reload.position
    assert_equal 0, other_turn.reload.position
  end

  test "a soft-deleted record stays out of its sequence" do
    append_scene("First")
    second = append_scene("Second")
    second.soft_delete

    SequenceNormalizer.new.call

    assert_contiguous @story.scenes
    assert_not_includes @story.scenes.reload, second
  end

  # The derivation is only as good as the guard on it. A positioned model missing from
  # this walk would keep every gap it is given, silently, so the list is held against
  # the routed controllers in both directions — the same pair `draft_applier_test.rb`
  # holds for the applier's own derivation.
  test "it walks exactly the models whose controllers maintain an ordered sequence" do
    assert_equal 16, positioned_models.size,
      "the number of ordered controllers is what this walk is checked against; a new one changes it"

    assert_equal positioned_models, SequenceNormalizer.positioned_models
  end

  test "each model's group columns are columns it actually has" do
    SequenceNormalizer.positioned_models.each do |model|
      columns = model.ordered_sequence_group_columns

      assert columns.all? { |column| model.column_names.include?(column.to_s) },
        "#{model.name} names #{columns.inspect} as its sequence group, which is not all of its own columns"
    end
  end

  # A model scoped some other way would be normalized in every universe while the caller
  # believed it had been restricted to one, so an unknown scope is refused rather than
  # quietly widened. A plain object rather than an `ApplicationRecord` subclass: an
  # anonymous one would stay in `descendants` for the rest of the process and break
  # every other test that walks it.
  test "it refuses a model whose sequence scope it cannot restrict to a universe" do
    unscoped = Class.new do
      def self.name = "SomeOtherScopedModel"
      def self.ordered_sequence_group_columns = [ :draft_id ]
    end

    assert_raises(ArgumentError) do
      SequenceNormalizer.new.send(:relation_for, unscoped, @universe)
    end
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

    def ordered(relation)
      relation.reorder(:position, :id).to_a
    end

    # A live sequence is exactly `0..n-1`: a gap shows as a length that does not match
    # the positions, a duplicate as a repeated number, and both at once as neither.
    def assert_contiguous(relation)
      positions = ordered(relation).map(&:position)

      assert_equal (0...positions.length).to_a, positions
    end

    # Walked from the routed controllers rather than from `ApplicationRecord.descendants`,
    # which holds only the models this process happened to load — two of the fifteen are
    # invisible to it until something references them.
    def positioned_models
      Rails.application.routes.routes.filter_map { |route| route.defaults[:controller] }.uniq.filter_map do |name|
        "#{name}_controller".camelize.safe_constantize
      end.select { |controller| controller.include?(MaintainsSiblingPositions) }
        .map { |controller| controller.new.send(:sibling_position_resource_name).to_s.classify.constantize }
        .uniq
        .sort_by(&:name)
    end
end
