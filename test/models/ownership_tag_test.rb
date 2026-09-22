require "test_helper"

class OwnershipTagTest < ActiveSupport::TestCase
  test "requires a name" do
    ownership_tag = OwnershipTag.new(universe: universes(:universe_one))

    assert_not ownership_tag.valid?
    assert_includes ownership_tag.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    ownership_tag = OwnershipTag.new(
      universe: universes(:universe_one),
      name: "Possesses",
      parent: OwnershipTag.create!(universe: universes(:universe_two), name: "Owns")
    )

    assert_not ownership_tag.valid?
    assert_includes ownership_tag.errors[:parent], "must belong to the same universe"
  end
end
