require "test_helper"

# The stored half of an import run: the identity the run wrote, the slice answers it
# keeps, and the one rule that matters — a run always names a source, a universe, and
# at least one slice.
class StoryInterchangeRunTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @operator = users(:platform_operator)
  end

  test "record! stores the universe as it was written and every slice's answer" do
    run = StoryInterchangeRun.record!(
      universe: @universe,
      replaced: true,
      outcomes: [ outcome(created: 3, skipped: [ "O-I1" ]) ],
      operator: @operator,
      source: "synthetic-universe"
    )

    assert_equal @operator, run.user
    assert_equal "synthetic-universe", run.source
    assert_equal @universe.name, run.universe_name
    assert_equal @universe.slug, run.universe_slug
    assert run.replaced?

    slice = run.slices.sole
    assert_equal "imports.slices.canon_rules", slice.label_key
    assert_equal 3, slice.created
    assert_equal [ "O-I1" ], slice.skipped
    assert slice.skipped?
    assert run.reported?
  end

  test "a run with nothing reported is still a run" do
    run = StoryInterchangeRun.record!(
      universe: @universe,
      replaced: false,
      outcomes: [ outcome(created: 1, skipped: []) ],
      operator: @operator,
      source: "synthetic-universe"
    )

    assert_not run.reported?
    assert_not run.slices.sole.skipped?
  end

  test "a run names its source, its universe, and at least one slice" do
    run = StoryInterchangeRun.new(user: @operator, source: "", universe_name: "", universe_slug: "", outcomes: [])

    assert_not run.valid?
    assert_includes run.errors[:source], "can't be blank"
    assert_includes run.errors[:universe_name], "can't be blank"
    assert_includes run.errors[:universe_slug], "can't be blank"
    assert_includes run.errors[:outcomes], "can't be blank"
  end

  private
    def outcome(created:, skipped:)
      StoryInterchange::Importer::Outcome.new(
        label_key: "imports.slices.canon_rules", created: created, skipped: skipped
      )
    end
end
