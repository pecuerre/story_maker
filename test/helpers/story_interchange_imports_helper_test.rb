require "test_helper"

# The sentence beside a record on the import preview and the run page. A record
# written whole says nothing; a record that lost something says what it lost.
class StoryInterchangeImportsHelperTest < ActionView::TestCase
  include StoryInterchangeImportsHelper

  Note = StoryInterchange::Importer::Note
  Record = StoryInterchange::Importer::Record

  test "a record written whole has no note to show" do
    assert_nil import_record_notes(record)
    assert_not record.reported?
  end

  test "each kind of leftover becomes one sentence naming it" do
    assert_equal "The text before the first section has no field, so it was not imported. " \
      "The frontmatter key “type” has no field, so it was not imported.",
      import_record_notes(record(Note.new(:introduction, nil), Note.new(:frontmatter, "type")))

    assert_equal "The section “Who is here” has no field, so it was not imported.",
      import_record_notes(record(Note.new(:section, "Who is here")))

    assert_equal "The reference “[[canon:K48]]” names no record this run writes, so it was left as written.",
      import_record_notes(record(Note.new(:reference, "[[canon:K48]]")))

    assert_equal "“International Lunar Programme” names no Faction, so no membership was created.",
      import_record_notes(record(Note.new(:affiliation, "International Lunar Programme")))
  end

  test "one kind lists every leftover it has" do
    notes = [ Note.new(:frontmatter, "type"), Note.new(:frontmatter, "controller"), Note.new(:frontmatter, "status") ]

    assert_equal "The frontmatter keys “type”, “controller”, and “status” have no field, so they were not imported.",
      import_record_notes(record(*notes))
  end

  test "a long list of leftovers is bounded and its tail counted" do
    notes = 5.times.map { |index| Note.new(:section, "Heading #{index}") }

    assert_equal "The sections “Heading 0”, “Heading 1”, “Heading 2” and 2 more have no field, so they were not imported.",
      import_record_notes(record(*notes))
  end

  test "a reported record whose leftovers were never stored still says so" do
    assert_equal "Some content has no field and was not imported.",
      import_record_notes(record(Note.new(:unspecified, nil)))
  end

  test "an unknown note kind falls back rather than raising" do
    assert_equal "Some content has no field and was not imported.",
      import_record_notes(record(Note.new(:retired_kind, "x")))
  end

  private
    def record(*notes)
      Record.new(name: "The Keep", slug: "keep", notes: notes)
    end
end
