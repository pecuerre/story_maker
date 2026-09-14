require "test_helper"

class ItemTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    item_type = ItemType.new(universe: universes(:universe_one))

    assert_not item_type.valid?
    assert_includes item_type.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    item_type = ItemType.new(universe: universes(:universe_one), name: "Child", parent: item_types(:item_type_three))

    assert_not item_type.valid?
    assert_includes item_type.errors[:parent], "must belong to the same universe"
  end

  test "rejects a descendant as parent" do
    root = ItemType.create!(universe: universes(:universe_one), name: "Root")
    child = ItemType.create!(universe: universes(:universe_one), name: "Child", parent: root)

    root.parent = child

    assert_not root.valid?
    assert_includes root.errors[:parent], "cannot be a descendant"
  end
end
