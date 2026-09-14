require "test_helper"

class OwnershipTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    ownership_type = OwnershipType.new(universe: universes(:universe_one))

    assert_not ownership_type.valid?
    assert_includes ownership_type.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    ownership_type = OwnershipType.new(
      universe: universes(:universe_one),
      name: "Possesses",
      parent: OwnershipType.create!(universe: universes(:universe_two), name: "Owns")
    )

    assert_not ownership_type.valid?
    assert_includes ownership_type.errors[:parent], "must belong to the same universe"
  end
end
