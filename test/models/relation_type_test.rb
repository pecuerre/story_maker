require "test_helper"

class RelationTypeTest < ActiveSupport::TestCase
  test "requires an inverse when not symmetric" do
    relation_type = RelationType.new(story: stories(:story_one), name: "Knows", symmetric: false)

    assert_not relation_type.valid?
    assert_includes relation_type.errors[:inverse], "can't be blank"
  end

  test "does not require an inverse when symmetric" do
    relation_type = RelationType.new(story: stories(:story_one), name: "Sibling", symmetric: true)

    assert relation_type.valid?
  end

  test "rejects a parent from another story" do
    relation_type = RelationType.new(story: stories(:story_one), name: "Knows", parent: RelationType.create!(story: stories(:story_two), name: "Parent"))

    assert_not relation_type.valid?
    assert_includes relation_type.errors[:parent], "must belong to the same story"
  end
end