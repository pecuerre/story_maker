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
end
