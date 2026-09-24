require "test_helper"

class RelationTagTest < ActiveSupport::TestCase
  test "requires an inverse when not symmetric" do
    relation_tag = RelationTag.new(universe: universes(:universe_one), name: "Knows", symmetric: false)

    assert_not relation_tag.valid?
    assert_includes relation_tag.errors[:inverse], "can't be blank"
  end

  test "does not require an inverse when symmetric" do
    relation_tag = RelationTag.new(universe: universes(:universe_one), name: "Sibling", symmetric: true)

    assert relation_tag.valid?
  end

  test "rejects a parent from another universe" do
    relation_tag = RelationTag.new(universe: universes(:universe_one), name: "Knows", parent: RelationTag.create!(universe: universes(:universe_two), name: "Parent"))

    assert_not relation_tag.valid?
    assert_includes relation_tag.errors[:parent], "must belong to the same universe"
  end
end
