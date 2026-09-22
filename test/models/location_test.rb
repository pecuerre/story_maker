require "test_helper"

class LocationTest < ActiveSupport::TestCase
  test "requires a name and location tag" do
    location = Location.new(universe: universes(:universe_one))

    assert_not location.valid?
    assert_includes location.errors[:name], "can't be blank"
    assert_includes location.errors[:location_tags], "can't be blank"
  end

  test "rejects a parent from another universe" do
    location = Location.new(universe: universes(:universe_one), name: "Child", location_tags: [ location_tags(:location_tag_one) ], parent: locations(:location_three))

    assert_not location.valid?
    assert_includes location.errors[:parent], "must belong to the same universe"
  end
end
