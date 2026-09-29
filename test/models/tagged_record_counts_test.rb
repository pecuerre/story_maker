require "test_helper"

class TaggedRecordCountsTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @other_universe = universes(:universe_two)
  end

  test "counts the records carrying each tag of a universe taxonomy" do
    tag = character_tags(:character_tag_one)
    other = character_tags(:character_tag_two)
    character = characters(:character_one)
    assert_empty character.character_tags - [ tag ]

    counts = TaggedRecordCounts.for(@universe.character_tags)

    assert_equal 1, counts[tag.id]
    assert_equal 1, counts[other.id]
    assert_equal @universe.character_tags.pluck(:id).sort, counts.keys.sort
  end

  test "reports zero for a tag nothing is assigned to" do
    counts = TaggedRecordCounts.for(@universe.event_tags)

    assert_equal @universe.event_tags.pluck(:id).sort, counts.keys.sort
    assert counts.values.all? { |count| count.zero? }, "expected no events to carry an event tag yet"
  end

  test "never counts a record from another universe" do
    foreign_tag = character_tags(:character_tag_three)
    refute_includes @universe.character_tags.pluck(:id), foreign_tag.id

    counts = TaggedRecordCounts.for(@universe.character_tags)

    assert_not_includes counts.keys, foreign_tag.id
  end

  test "keeps story-scoped taxonomies inside their own story" do
    story = stories(:story_one)
    tag = section_tags(:section_tag_one)
    other_story_tag = section_tags(:section_tag_three)
    counts = TaggedRecordCounts.for(story.section_tags)

    assert_equal 1, counts[tag.id]
    assert_equal 0, counts.fetch(other_story_tag.id, 0) if counts.key?(other_story_tag.id)
    assert_not_includes counts.keys, other_story_tag.id
  end

  test "agrees with the scoped association for every tag" do
    [ @universe.character_tags, @universe.location_tags, @universe.item_tags,
      stories(:story_one).section_tags, stories(:story_one).scene_tags ].each do |records|
      counts = TaggedRecordCounts.for(records)

      records.each do |record|
        assert_equal record.tagged_records.count, counts.fetch(record.id),
          "expected #{record.class} #{record.name} to be counted consistently"
      end
    end
  end

  test "returns an empty hash for a taxonomy with no tags" do
    assert_equal({}, TaggedRecordCounts.for(@universe.relation_tags.where(id: 0)))
  end

  # A soft delete keeps the record's join-table rows so a restore is complete, and
  # this query is raw SQL, so the element model's `default_scope` does not apply.
  # The exclusion has to be restated in the query, or a deleted record stays in its
  # tags' count pills while being invisible everywhere else.
  test "stops counting a soft-deleted record while its join rows are kept" do
    tag = character_tags(:character_tag_one)
    character = characters(:character_one)
    assert_equal 1, TaggedRecordCounts.for(@universe.character_tags)[tag.id]

    character.soft_delete

    assert_empty Character.where(id: character.id), "the record must be hidden from ordinary queries"
    assert_equal 1, ActiveRecord::Base.connection.select_value(
      "SELECT COUNT(*) FROM characters_character_tags WHERE character_id = #{character.id}"
    ).to_i, "the join row is kept so a restore is complete"
    assert_equal 0, TaggedRecordCounts.for(@universe.character_tags)[tag.id],
      "a soft-deleted record must not still be counted"
  end

  test "counts a restored record again" do
    tag = character_tags(:character_tag_one)
    character = characters(:character_one)

    character.soft_delete
    character.restore

    assert_equal 1, TaggedRecordCounts.for(@universe.character_tags)[tag.id]
  end

  test "excludes soft-deleted records in a story-scoped taxonomy too" do
    story = stories(:story_one)
    tag = section_tags(:section_tag_one)
    section = story.sections.first
    tag.sections << section unless tag.sections.include?(section)

    before = TaggedRecordCounts.for(story.section_tags)[tag.id]
    section.soft_delete

    assert_equal before - 1, TaggedRecordCounts.for(story.section_tags)[tag.id],
      "a soft-deleted section must drop out of its tag's count"
  end
end
