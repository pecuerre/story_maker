require "test_helper"

class ItemTagTest < ActiveSupport::TestCase
  test "requires a name" do
    item_tag = ItemTag.new(universe: universes(:universe_one))

    assert_not item_tag.valid?
    assert_includes item_tag.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    item_tag = ItemTag.new(universe: universes(:universe_one), name: "Child", parent: item_tags(:item_tag_three))

    assert_not item_tag.valid?
    assert_includes item_tag.errors[:parent], "must belong to the same universe"
  end

  test "rejects a descendant as parent" do
    root = ItemTag.create!(universe: universes(:universe_one), name: "Root")
    child = ItemTag.create!(universe: universes(:universe_one), name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end
end
