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
      outcomes: [ outcome(created: 3, reported: [ reported_record(name: "The Warden", slug: "warden", sections: 2, words: 40) ]) ],
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
    record = slice.reported.sole
    assert_equal "The Warden", record.label
    assert_equal 2, record.sections
    assert_equal 40, record.words
    assert slice.reported?
    assert run.reported?
  end

  test "a run with nothing reported is still a run" do
    run = StoryInterchangeRun.record!(
      universe: @universe,
      replaced: false,
      outcomes: [ outcome(created: 1, reported: []) ],
      operator: @operator,
      source: "synthetic-universe"
    )

    assert_not run.reported?
    assert_not run.slices.sole.reported?
  end

  test "a run written before the counts existed still renders its reported records" do
    run = StoryInterchangeRun.create!(
      user: @operator,
      source: "synthetic-universe",
      universe_name: @universe.name,
      universe_slug: @universe.slug,
      replaced: false,
      outcomes: [ {
        "label_key" => "imports.slices.locations",
        "created" => 1,
        "skipped" => [ "keep: type", "keep: Open questions" ]
      } ]
    )

    slice = run.slices.sole
    assert slice.reported?
    assert_equal [ "keep" ], slice.reported.map(&:label)
    assert_equal [ [ "keep: type", "keep: Open questions" ] ], slice.reported.map(&:items)
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
    def outcome(created:, reported:)
      StoryInterchange::Importer::Outcome.new(
        label_key: "imports.slices.canon_rules", created: created, reported: reported
      )
    end

    def reported_record(name:, slug:, sections:, words:)
      StoryInterchange::Importer::Reported.new(
        name: name, slug: slug, sections: sections, words: words, items: []
      )
    end
end
