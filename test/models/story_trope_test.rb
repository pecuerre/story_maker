require "test_helper"

class StoryTropeTest < ActiveSupport::TestCase
  test "a catalogue trope can be annotated at Story scope" do
    assignment = StoryTrope.new(story: stories(:story_one), trope_slug: "found-family", context_note: "The crew builds trust.")

    assert_predicate assignment, :valid?
    assert_equal "Found Family", assignment.trope.name
  end

  test "an unknown trope slug is refused" do
    assignment = StoryTrope.new(story: stories(:story_one), trope_slug: "unknown")

    assert_not assignment.valid?
    assert_includes assignment.errors[:trope_slug], "is not included in the list"
  end

  test "the same trope is unique within a Story but can be used by another Story" do
    duplicate = StoryTrope.new(story: stories(:story_one), trope_slug: "red-herring")
    elsewhere = StoryTrope.new(story: stories(:story_alt), trope_slug: "red-herring")

    assert_not duplicate.valid?
    assert_predicate elsewhere, :valid?
  end

  test "Story soft deletion retains annotations for restoration" do
    assignment = story_tropes(:story_one_red_herring)

    stories(:story_one).soft_delete

    assert StoryTrope.exists?(assignment.id)
    stories(:story_one).restore
    assert_equal "red-herring", stories(:story_one).story_tropes.first.trope_slug
  end
end
