require "test_helper"

class EventTest < ActiveSupport::TestCase
  test "requires at least a title, a date, or a relation to another event" do
    event = Event.new(universe: universes(:universe_one))

    assert_not event.valid?
    assert_includes event.errors[:base], "must have a title, a date, or a relation to another event"
  end

  test "is valid with only a title" do
    event = Event.new(universe: universes(:universe_one), title: "A title")

    assert event.valid?
  end

  test "derives its name and slug from the title when created" do
    event = Event.create!(universe: universes(:universe_one), title: "A title")

    assert_equal "A title", event.name
    assert_equal "a-title", event.slug
  end

  test "keeps its name and slug synchronized with a changed title" do
    event = Event.create!(universe: universes(:universe_one), title: "Original title")

    event.update!(title: "Renamed title")

    assert_equal "Renamed title", event.name
    assert_equal "renamed-title", event.slug
  end

  test "updates the name and slug when a title is added or cleared" do
    event = Event.create!(universe: universes(:universe_one), start_datetime: Time.current)

    event.update!(title: "Named event")
    assert_equal "Named event", event.name
    assert_equal "named-event", event.slug

    event.update!(title: nil)
    assert_nil event.name
    assert event.slug.present?
  end

  test "is valid with only a start date" do
    event = Event.new(universe: universes(:universe_one), start_datetime: Time.current)

    assert event.valid?
  end

  test "is valid with only a before_event relation" do
    event = Event.new(universe: universes(:universe_one), before_event: events(:event_one))

    assert event.valid?
  end

  test "cannot reference itself" do
    event = events(:event_one)
    event.before_event_id = event.id

    assert_not event.valid?
    assert_includes event.errors[:before_event], "cannot be itself"
  end

  test "cannot reference itself before persistence" do
    event = Event.new(universe: universes(:universe_one))
    event.before_event = event
    event.after_event = event
    event.simultaneous_event = event

    assert_not event.valid?
    assert_includes event.errors[:before_event], "cannot be itself"
    assert_includes event.errors[:after_event], "cannot be itself"
    assert_includes event.errors[:simultaneous_event], "cannot be itself"
  end

  test "cannot reference a manually assigned id before persistence" do
    event = Event.new(id: 12_345, universe: universes(:universe_one), title: "Self reference", before_event_id: 12_345)

    assert_not event.valid?
    assert_includes event.errors[:before_event], "cannot be itself"
  end

  test "database constraints reject direct self references" do
    event = events(:event_one)

    assert_raises ActiveRecord::StatementInvalid do
      Event.where(id: event.id).update_all(before_event_id: event.id)
    end
    assert_nil event.reload.before_event_id
  end

  test "destroy clears every temporal reference to the event" do
    event = events(:event_one)
    before_reference = Event.create!(universe: event.universe, title: "Before", before_event: event)
    after_reference = Event.create!(universe: event.universe, title: "After", after_event: event)
    simultaneous_reference = Event.create!(universe: event.universe, title: "Simultaneous", simultaneous_event: event)

    assert_difference("Event.count", -1) do
      event.destroy!
    end

    assert_nil before_reference.reload.before_event
    assert_nil after_reference.reload.after_event
    assert_nil simultaneous_reference.reload.simultaneous_event
  end

  test "destroy removes a relation-only referrer that would no longer be identifiable" do
    event = Event.create!(universe: universes(:universe_one), title: "Referenced")
    reference = Event.create!(universe: event.universe, before_event: event)

    assert_difference("Event.count", -2) do
      event.destroy!
    end

    assert_not Event.exists?(reference.id)
  end

  test "destroy handles relation-only reference cycles" do
    universe = universes(:universe_one)
    first = Event.create!(universe: universe, title: "First")
    second = Event.create!(universe: universe, title: "Second")
    first.update!(before_event: second)
    second.update!(before_event: first)
    first.update_columns(title: nil, start_datetime: nil, end_datetime: nil)
    second.update_columns(title: nil, start_datetime: nil, end_datetime: nil)

    assert_difference("Event.count", -2) do
      first.destroy!
    end
  end

  test "universe destruction clears temporal references between its events" do
    universe = Universe.create!(owner: users(:user_one), name: "Temporal universe", slug: "temporal-universe")
    event = Event.create!(universe: universe, title: "Referenced")
    reference = Event.create!(universe: universe, title: "Reference", before_event: event)

    assert_difference("Event.count", -2) do
      universe.destroy!
    end

    assert_not Event.exists?(reference.id)
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
