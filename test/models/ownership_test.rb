require "test_helper"

class OwnershipTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @ownership_type = OwnershipType.create!(universe: @universe, name: "Owns")
  end

  test "requires an item, character, and ownership type" do
    ownership = Ownership.new(universe: @universe)

    assert_not ownership.valid?
    assert_includes ownership.errors[:item], "can't be blank"
    assert_includes ownership.errors[:character], "can't be blank"
    assert_includes ownership.errors[:ownership_types], "can't be blank"
  end

  test "rejects associated records from another universe" do
    ownership = Ownership.new(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_types: [ OwnershipType.create!(universe: universes(:universe_two), name: "Owns") ]
    )

    assert_not ownership.valid?
    assert_includes ownership.errors[:ownership_types], "must belong to the ownership's universe"
  end

  test "allows repeated ownerships" do
    attributes = {
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_types: [ @ownership_type ]
    }

    assert Ownership.create!(attributes)
    assert Ownership.create!(attributes)
  end
end
