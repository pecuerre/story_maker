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

  # The stored label is what a search document carries and one index serves every
  # reader, so it is resolved in the default locale whatever the request is. These
  # are the *stored* strings: changing one is an index-content change, and
  # `bin/rails search:reindex` is what makes an existing index agree.
  test "the stored label is the default locale's, whatever the request asks for" do
    referenced = events(:event_one)
    titled = Event.new(title: "Battle", start_datetime: Time.zone.parse("2026-01-01 10:00"))
    dated = Event.new(start_datetime: Time.zone.parse("2026-01-01 10:00"))
    ended = Event.new(end_datetime: Time.zone.parse("2026-01-02 10:00"))
    before = Event.new(before_event: referenced)
    after_that = Event.new(after_event: referenced)
    simultaneous = Event.new(simultaneous_event: referenced)
    unnamed = Event.new

    I18n.with_locale(:es) do
      assert_equal "Battle - 2026-01-01 10:00", titled.display_string
      assert_equal "2026-01-01 10:00", dated.display_string
      assert_equal "2026-01-02 10:00", ended.display_string
      assert_equal "before #{referenced.display_string}", before.display_string
      assert_equal "after #{referenced.display_string}", after_that.display_string
      assert_equal "same time as #{referenced.display_string}", simultaneous.display_string
      assert_equal "Event ##{unnamed.id}", unnamed.display_string
    end
  end

  test "the reader's label is the same ladder in the reader's language" do
    referenced = events(:event_one)
    titled = Event.new(title: "Battle", start_datetime: Time.zone.parse("2026-01-01 10:00"))
    dated = Event.new(start_datetime: Time.zone.parse("2026-01-01 10:00"))
    ended = Event.new(end_datetime: Time.zone.parse("2026-01-02 10:00"))
    before = Event.new(before_event: referenced)
    after_that = Event.new(after_event: referenced)
    simultaneous = Event.new(simultaneous_event: referenced)
    unnamed = Event.new

    # In the default locale the two forms are the same string, for every shape the
    # ladder can take. That is what makes one of them safe to store.
    [ titled, dated, ended, before, after_that, simultaneous, unnamed ].each do |event|
      assert_equal event.display_string, event.display_label
    end

    I18n.with_locale(:es) do
      # A title and a date are the author's own words, so only the relationship
      # phrases and the unnamed fallback move.
      assert_equal "Battle - 2026-01-01 10:00", titled.display_label
      assert_equal "2026-01-01 10:00", dated.display_label
      assert_equal "2026-01-02 10:00", ended.display_label
      assert_equal "antes de #{referenced.display_label}", before.display_label
      assert_equal "después de #{referenced.display_label}", after_that.display_label
      assert_equal "al mismo tiempo que #{referenced.display_label}", simultaneous.display_label
      assert_equal "Suceso n.º #{unnamed.id}", unnamed.display_label
    end
  end

  test "a chain of relationships is labelled in the reader's language throughout" do
    # The ladder is walked with the reader's own method, so a relationship of a
    # relationship is not one translated phrase wrapped around an English one.
    oldest = Event.create!(universe: universes(:universe_one), title: "Arrival")
    middle = Event.create!(universe: universes(:universe_one), before_event: oldest)
    newest = Event.create!(universe: universes(:universe_one), before_event: middle)

    I18n.with_locale(:es) { assert_equal "antes de antes de #{oldest.name}", newest.display_label }
    assert_equal "before before #{oldest.name}", newest.display_string
  end

  test "a cycle of relationships still answers rather than recursing forever" do
    # Two events that only identify each other are the case the `visited` list
    # exists for: the walk stops at the record it has already been through and
    # names it by its id, in whichever language asked.
    first = Event.create!(universe: universes(:universe_one), title: "First")
    second = Event.create!(universe: universes(:universe_one), after_event: first)
    first.update!(title: nil, after_event: second)

    I18n.with_locale(:es) do
      # Each label names the other and then the record the walk has already been
      # through, by its id — which is the point: the cycle terminates instead of
      # being followed.
      assert_equal "después de después de Suceso n.º #{first.id}", first.display_label
      assert_equal "después de después de Suceso n.º #{second.id}", second.display_label
    end
  end
end
