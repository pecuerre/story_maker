require "test_helper"

class LocationTagTest < ActiveSupport::TestCase
  test "requires a name" do
    location_tag = LocationTag.new(universe: universes(:universe_one))

    assert_not location_tag.valid?
    assert_includes location_tag.errors[:name], "can't be blank"
  end

  test "rejects a parent from another universe" do
    location_tag = LocationTag.new(universe: universes(:universe_one), name: "Child", parent: location_tags(:location_tag_three))

    assert_not location_tag.valid?
    assert_includes location_tag.errors[:parent], "must belong to the same universe"
  end
end
