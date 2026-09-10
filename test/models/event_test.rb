require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "requires at least a title, a date, or a relation to another event" do
    event = Event.new(story: stories(:story_one))

    assert_not event.valid?
    assert_includes event.errors[:base], "must have a title, a date, or a relation to another event"
  end

  test "is valid with only a title" do
    event = Event.new(story: stories(:story_one), title: "A title")

    assert event.valid?
  end

  test "is valid with only a start date" do
    event = Event.new(story: stories(:story_one), start_datetime: Time.current)

    assert event.valid?
  end

  test "is valid with only a before_event relation" do
    event = Event.new(story: stories(:story_one), before_event: events(:event_one))

    assert event.valid?
  end

  test "cannot reference itself" do
    event = events(:event_one)
    event.before_event_id = event.id

    assert_not event.valid?
    assert_includes event.errors[:before_event], "cannot be itself"
  end

  test "display_string prefers title and start datetime together" do
    event = Event.new(title: "Battle", start_datetime: Time.zone.parse("2026-01-01 10:00"))

    assert_equal "Battle - 2026-01-01 10:00", event.display_string
  end

  test "display_string falls back to the before_event relation" do
    referenced = events(:event_one)
    event = Event.new(before_event: referenced)

    assert_equal "before #{referenced.display_string}", event.display_string
  end
end
