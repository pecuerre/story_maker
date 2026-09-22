require "test_helper"

class EventTagTest < ActiveSupport::TestCase
  test "requires a name" do
    event_tag = EventTag.new(universe: universes(:universe_one))

    assert_not event_tag.valid?
    assert_includes event_tag.errors[:name], "can't be blank"
  end

  test "defaults to a light gray color" do
    event_tag = EventTag.create!(universe: universes(:universe_one), name: "New tag")

    assert_equal "#d3d3d3", event_tag.bgcolor
  end

  test "requires a valid hex background color" do
    event_tag = EventTag.new(universe: universes(:universe_one), name: "New tag", bgcolor: "red")

    assert_not event_tag.valid?
    assert_includes event_tag.errors[:bgcolor], "must be a hex color like #d3d3d3"
  end

  test "rejects a parent from another universe" do
    event_tag = EventTag.new(universe: universes(:universe_one), name: "Child", parent: event_tags(:event_tag_three))

    assert_not event_tag.valid?
    assert_includes event_tag.errors[:parent], "must belong to the same universe"
  end
end
