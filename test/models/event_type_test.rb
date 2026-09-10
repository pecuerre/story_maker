require "test_helper"

class EventTypeTest < ActiveSupport::TestCase
  test "requires a name" do
    event_type = EventType.new(story: stories(:story_one))

    assert_not event_type.valid?
    assert_includes event_type.errors[:name], "can't be blank"
  end

  test "defaults to a light gray color" do
    event_type = EventType.create!(story: stories(:story_one), name: "New type")

    assert_equal "#d3d3d3", event_type.color
  end

  test "requires a valid hex color" do
    event_type = EventType.new(story: stories(:story_one), name: "New type", color: "red")

    assert_not event_type.valid?
    assert_includes event_type.errors[:color], "must be a hex color like #d3d3d3"
  end

  test "rejects a parent from another story" do
    event_type = EventType.new(story: stories(:story_one), name: "Child", parent: event_types(:event_type_three))

    assert_not event_type.valid?
    assert_includes event_type.errors[:parent], "must belong to the same story"
  end
end
