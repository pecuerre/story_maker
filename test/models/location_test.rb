require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "requires a name" do
    location = Location.new(universe: universes(:universe_one))

    assert_not location.valid?
    assert_includes location.errors[:name], "can't be blank"
  end

  test "allows a location without tags" do
    assert Location.create!(universe: universes(:universe_one), name: "Untagged")
  end

  test "rejects a parent from another universe" do
    location = Location.new(universe: universes(:universe_one), name: "Child", location_tags: [ location_tags(:location_tag_one) ], parent: locations(:location_three))

    assert_not location.valid?
    assert_includes location.errors[:parent], "must belong to the same universe"
  end

  test "rejects a universe change while child locations exist" do
    location = Location.create!(universe: universes(:universe_one), name: "Parent")
    Location.create!(universe: universes(:universe_one), name: "Child", parent: location)

    assert_not location.update(universe: universes(:universe_two))
    assert_includes location.errors[:universe_id], "cannot be changed while child records exist"
    assert_equal universes(:universe_one).id, location.reload.universe_id
  end

  test "allows a universe change without dependents" do
    location = Location.create!(universe: universes(:universe_one), name: "Mover")

    assert location.update(universe: universes(:universe_two))
    assert_equal universes(:universe_two).id, location.reload.universe_id
  end
end
