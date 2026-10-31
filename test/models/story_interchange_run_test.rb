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
      outcomes: [ outcome(created: 2, records: [
        record(name: "The Warden", slug: "warden", notes: [ [ :section, "Who is here" ], [ :frontmatter, "type" ] ]),
        record(name: "The Gate", slug: "gate")
      ]) ],
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
    assert_equal 2, slice.created
    # Every record is kept, not only the one that lost content, so the page can
    # list the whole slice.
    assert_equal [ "The Warden", "The Gate" ], slice.records.map(&:label)
    record = slice.reported.sole
    assert_equal "The Warden", record.label
    # The note survives the round trip, so the page can still name what was
    # left behind after the source is gone.
    assert_equal [ [ :section, "Who is here" ], [ :frontmatter, "type" ] ],
      record.notes.map { |note| [ note.kind, note.subject ] }
    assert slice.reported?
    assert run.reported?
  end

  test "a run with nothing reported still lists every record" do
    run = StoryInterchangeRun.record!(
      universe: @universe,
      replaced: false,
      outcomes: [ outcome(created: 1, records: [ record(name: "The Gate", slug: "gate") ]) ],
      operator: @operator,
      source: "synthetic-universe"
    )

    slice = run.slices.sole
    assert_equal [ "The Gate" ], slice.records.map(&:label)
    assert_not run.reported?
    assert_not slice.reported?
  end

  test "a run written before every record was stored still renders its reported records" do
    run = StoryInterchangeRun.create!(
      user: @operator,
      source: "synthetic-universe",
      universe_name: @universe.name,
      universe_slug: @universe.slug,
      replaced: false,
      outcomes: [ {
        "label_key" => "imports.slices.locations",
        "created" => 2,
        "reported" => [ { "name" => "The Keep", "slug" => "keep", "sections" => 1, "words" => 30 } ]
      } ]
    )

    slice = run.slices.sole
    assert slice.reported?
    assert_equal [ "The Keep" ], slice.reported.map(&:label)
    # The row kept counts rather than the leftovers themselves, so the page can
    # still say the record was reported but not what it left behind.
    assert_equal [ :unspecified ], slice.reported.sole.notes.map(&:kind)
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
    assert_equal [ :unspecified ], slice.reported.sole.notes.map(&:kind)
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
    def outcome(created:, records:)
      StoryInterchange::Importer::Outcome.new(
        label_key: "imports.slices.canon_rules", created: created, records: records
      )
    end

    def record(name:, slug:, notes: [])
      StoryInterchange::Importer::Record.new(
        name: name,
        slug: slug,
        notes: notes.map { |kind, subject| StoryInterchange::Importer::Note.new(kind: kind, subject: subject) }
      )
    end
end
