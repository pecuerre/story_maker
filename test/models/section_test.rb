require "test_helper"

class SectionTest < ActiveSupport::TestCase
  setup do
    @story = stories(:story_one)
  end

  test "requires a story" do
    section = Section.new(name: "Orphan")

    assert_not section.valid?
    assert_includes section.errors[:story], "must exist"
  end

  test "accepts a parent from the same story" do
    section = Section.new(
      story: @story,
      name: "Child",
      parent: sections(:section_one),
      section_tags: [ section_tags(:section_tag_one) ]
    )

    assert section.valid?
  end

  test "allows a section without tags" do
    assert Section.create!(story: @story, name: "Untagged")
  end

  test "rejects a parent from another story" do
    section = Section.new(
      story: stories(:story_alt),
      name: "Child",
      parent: sections(:section_one),
      section_tags: [ section_tags(:section_tag_one) ]
    )

    assert_not section.valid?
    assert_includes section.errors[:parent], "must belong to the same story"
  end

  test "rejects a section tag from another story" do
    section = Section.new(
      story: @story,
      name: "Child",
      section_tags: [ section_tags(:section_tag_three) ]
    )

    assert_not section.valid?
    assert_includes section.errors[:section_tags], "must belong to the same story"
  end

  test "sections of a story are found through their universe" do
    assert_includes universes(:universe_one).sections, sections(:section_one)
    assert_not_includes universes(:universe_two).sections, sections(:section_one)
  end
end
