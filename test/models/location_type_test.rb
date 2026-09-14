require "test_helper"

class LocationTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    location_type = LocationType.new(universe: universes(:universe_one))

    assert_not location_type.valid?
    assert_includes location_type.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    location_type = LocationType.new(universe: universes(:universe_one), name: "Child", parent: location_types(:location_type_three))

    assert_not location_type.valid?
    assert_includes location_type.errors[:parent], "must belong to the same universe"
  end
end
