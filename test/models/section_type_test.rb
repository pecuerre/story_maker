require "test_helper"

class SectionTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    section_type = SectionType.new(story: stories(:story_one))

    assert_not section_type.valid?
    assert_includes section_type.errors[:name], "can't be blank"
  end

  test "rejects a parent from another story" do
    section_type = SectionType.new(story: stories(:story_one), name: "Child", parent: section_types(:section_type_three))

    assert_not section_type.valid?
    assert_includes section_type.errors[:parent], "must belong to the same story"
  end

  test "rejects a descendant as parent" do
    root = SectionType.create!(story: stories(:story_one), name: "Root")
    child = SectionType.create!(story: stories(:story_one), name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end
end
