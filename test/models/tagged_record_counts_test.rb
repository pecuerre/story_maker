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
end
