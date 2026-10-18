require "test_helper"

# The Events list filter is a value object, and it is worth covering on its own
# because the request tests can only show the outcome, not which part of the
# query produced it, what it did with a value it could not use, or which order
# a choice really took. Like the other two filters on a **flat** list, its own
# rules are pinned here rather than in the shared contract's test, and the one
# thing this class owns is the day range its list's own span is made of.
class EventFilterTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @event_tags = @universe.event_tags.reorder(:position, :id).to_a

    # Fixed timestamps, because "newest first" and "recently edited first" are
    # only meaningful when the fixtures are not all stamped within the same
    # microsecond of each other by the fixture loader. Every event gets them
    # explicitly, the last one too, and `name` is assigned like a title a reader
    # sees, so no event is ever the newest by accident or sorts as a blank.
    @event_one = events(:event_one)
    @event_one.update!(name: @event_one.title,
      created_at: Time.utc(2026, 9, 11, 8, 0, 0), updated_at: Time.utc(2026, 9, 11, 9, 0, 0))
    @event_two = events(:event_two)
    @event_two.update!(name: @event_two.title,
      created_at: Time.utc(2026, 9, 11, 10, 0, 0), updated_at: Time.utc(2026, 9, 11, 11, 0, 0))
    @event_three = @universe.events.create!(title: "The following day", start_datetime: Time.utc(2026, 9, 12, 8, 30, 0))
    @event_three.update!(created_at: Time.utc(2026, 9, 1, 0, 0, 0), updated_at: Time.utc(2026, 9, 20, 0, 0, 0))
    @event_without_start = @universe.events.create!(title: "A title without a start")
    @event_without_start.update!(created_at: Time.utc(2026, 9, 5, 0, 0, 0), updated_at: Time.utc(2026, 9, 6, 0, 0, 0))
    @event_one.update!(event_tag_ids: [ event_tags(:event_tag_one).id ])
  end

  test "an empty filter changes nothing, orders by name, and reports itself inactive" do
    filter = filter_for

    assert_not filter.active?
    assert_not filter.narrowed?
    assert_empty filter.query_params
    assert_empty filter.discarded
    assert_equal "name", filter.sort
    assert_equal [ @event_without_start.name, @event_one.name, @event_two.name, @event_three.name ],
      apply(filter).map(&:name)
  end

  test "free text matches the name or the description, ignoring case" do
    @event_one.update!(description: "The keeper of the gate")

    assert_equal [ @event_one.name ], apply(filter_for(q: "keeper")).map(&:name)
    assert_equal [ @event_one.name ], apply(filter_for(q: "KEEPER")).map(&:name),
      "a search box ignores case"
    assert_equal [ @event_two.name ], apply(filter_for(q: "The end")).map(&:name)
  end

  test "the tag filter narrows to the records carrying a tag" do
    assert_equal [ @event_one.name ],
      apply(filter_for(event_tag_id: event_tags(:event_tag_one).id)).map(&:name)
  end

  test "a grouping tag is still filterable even though the editor cannot assign it" do
    # `event_tag_two` is `taggable: false`, so the editor's picker omits it, but
    # the filter validates against every tag: no event carries this one, so the
    # reader is shown an empty list, never a dropped value.
    assert_not event_tags(:event_tag_two).taggable?
    grouping = filter_for(event_tag_id: event_tags(:event_tag_two).id)

    assert grouping.active?
    assert_empty apply(grouping).map(&:name)
  end

  test "a tag that is not in this universe is dropped and reported" do
    foreign = filter_for(event_tag_id: event_tags(:event_tag_three).id)

    assert_not foreign.active?
    assert_equal 1, foreign.discarded.size
    assert_match(/not an event tag of this universe/, foreign.discarded.first)
    assert_equal [ @event_without_start.name, @event_one.name, @event_two.name, @event_three.name ],
      apply(foreign).map(&:name)
  end

  test "the reader can choose an order, and each choice really reorders the list" do
    assert_equal [ @event_two.name, @event_one.name, @event_without_start.name, @event_three.name ],
      apply(filter_for(sort: "created")).map(&:name),
      "newest first"
    assert_equal [ @event_three.name, @event_two.name, @event_one.name, @event_without_start.name ],
      apply(filter_for(sort: "updated")).map(&:name),
      "recently edited first"
  end

  test "an order is resolved against an allowlist, so a hand-edited URL cannot choose one" do
    forged = filter_for(sort: "name; DROP TABLE events")

    assert_equal "name", forged.sort, "an order this list does not offer falls back to the default"
    assert_equal 1, forged.discarded.size
    assert_match(/not one this list offers/, forged.discarded.first)
    assert_equal [ @event_without_start.name, @event_one.name, @event_two.name, @event_three.name ],
      apply(forged).map(&:name)  end

  test "a sort narrows nothing, so it is active without being a narrowing" do
    sorted = filter_for(sort: "created")

    assert sorted.active?, "the reader did ask for something"
    assert_not sorted.narrowed?, "but an order cannot select a record or empty a list"
    assert_equal({ sort: "created" }, sorted.query_params)
  end

  test "the default order is never spelled out in the canonical query" do
    assert_empty filter_for.query_params
    assert_equal({}, filter_for(sort: "name").query_params)
    assert_equal({ sort: "created" }, filter_for(sort: "created").query_params)
  end

  test "records that tie on the chosen order keep a stable order across requests" do
    @event_two.update!(title: @event_one.title)

    first = apply(filter_for).map(&:id)
    second = apply(filter_for).map(&:id)

    assert_equal first, second, "two readers opening the same link see the same list"
    assert_equal first.sort, second.sort, "the tiebreaker is the id"
  end

  test "a sort never renumbers anything" do
    positions = @universe.events.pluck(:id, :position).to_h

    filter_for(sort: "created").apply(@universe.events).to_a

    assert_equal positions, @universe.events.pluck(:id, :position).to_h,
      "choosing an order is a read, never a write"
  end

  test "a day range is inclusive of the whole bound day" do
    assert_equal [ @event_one.name, @event_two.name, @event_three.name ],
      apply(filter_for(from: "2026-09-11")).map(&:name),
      "a day alone runs from that day onwards"
    assert_equal [ @event_one.name, @event_two.name, @event_three.name ],
      apply(filter_for(from: "2026-09-11", to: "2026-09-12")).map(&:name),
      "the bounds are the whole of two days"
  end

  test "a day range reaches up to the end of its last day" do
    assert_equal [ @event_one.name, @event_two.name ],
      apply(filter_for(to: "2026-09-11")).map(&:name),
      "an event later the same day is still inside them"
    assert_empty apply(filter_for(to: "2026-09-10")).map(&:name),
      "an event starting after the bound day is outside it"
  end

  test "an event without a start is excluded while a bound is set" do
    assert_equal [ @event_three.name ],
      apply(filter_for(from: "2026-09-12")).map(&:name),
      "a record with no start has no time to be inside a range"
  end

  test "an unreadable day is reported rather than guessed at, and the rest still applies" do
    broken = filter_for(from: "not-a-date", q: "The end")

    assert_equal [ @event_two.name ], apply(broken).map(&:name)
    assert_equal 1, broken.discarded.size
    assert_match(/could not be read/, broken.discarded.first)
    assert_equal({ q: "The end" }, broken.query_params)
  end

  private
    def filter_for(**params)
      EventFilter.new(params, event_tags: @event_tags)
    end

    def apply(filter)
      filter.apply(@universe.events).to_a
    end
end
