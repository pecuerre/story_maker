require "test_helper"

class SectionTagTest < ActiveSupport::TestCase
  test "requires a name" do
    section_tag = SectionTag.new(story: stories(:story_one))

    assert_not section_tag.valid?
    assert_includes section_tag.errors[:name], "can't be blank"
  end

  test "rejects a parent from another story" do
    section_tag = SectionTag.new(story: stories(:story_one), name: "Child", parent: section_tags(:section_tag_three))

    assert_not section_tag.valid?
    assert_includes section_tag.errors[:parent], "must belong to the same story"
  end

  test "rejects a descendant as parent" do
    root = SectionTag.create!(story: stories(:story_one), name: "Root")
    child = SectionTag.create!(story: stories(:story_one), name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end

  test "belongs to a story instead of a universe" do
    section_tag = section_tags(:section_tag_one)

    assert_equal stories(:story_one), section_tag.story
    assert_equal universes(:universe_one), section_tag.story.universe
    assert_not section_tag.respond_to?(:universe)
  end
end
