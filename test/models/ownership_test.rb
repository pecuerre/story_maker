require "test_helper"

class OwnershipTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @ownership_tag = OwnershipTag.create!(universe: @universe, name: "Owns")
  end

  test "requires an item, character, and ownership tag" do
    ownership = Ownership.new(universe: @universe)

    assert_not ownership.valid?
    assert_includes ownership.errors[:item], "can't be blank"
    assert_includes ownership.errors[:character], "can't be blank"
    assert_includes ownership.errors[:ownership_tags], "can't be blank"
  end

  test "rejects associated records from another universe" do
    ownership = Ownership.new(
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_tags: [ OwnershipTag.create!(universe: universes(:universe_two), name: "Owns") ]
    )

    assert_not ownership.valid?
    assert_includes ownership.errors[:ownership_tags], "must belong to the ownership's universe"
  end

  test "allows repeated ownerships" do
    attributes = {
      universe: @universe,
      item: items(:item_one),
      character: characters(:character_one),
      ownership_tags: [ @ownership_tag ]
    }

    assert Ownership.create!(attributes)
    assert Ownership.create!(attributes)
  end
end
