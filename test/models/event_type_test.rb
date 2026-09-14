require "test_helper"

class EventTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    event_type = EventType.new(universe: universes(:universe_one))

    assert_not event_type.valid?
    assert_includes event_type.errors[:name], "can't be blank"
  end

  test "defaults to a light gray color" do
    event_type = EventType.create!(universe: universes(:universe_one), name: "New type")

    assert_equal "#d3d3d3", event_type.bgcolor
  end

  test "requires a valid hex background color" do
    event_type = EventType.new(universe: universes(:universe_one), name: "New type", bgcolor: "red")

    assert_not event_type.valid?
    assert_includes event_type.errors[:bgcolor], "must be a hex color like #d3d3d3"
  end

  test "rejects a parent from another universe" do
    event_type = EventType.new(universe: universes(:universe_one), name: "Child", parent: event_types(:event_type_three))

    assert_not event_type.valid?
    assert_includes event_type.errors[:parent], "must belong to the same universe"
  end
end
