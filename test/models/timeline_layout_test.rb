require "test_helper"

class TimelineLayoutTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
  end

  test "orders events by non-overlapping start/end ranges" do
    early = @universe.events.create!(title: "Early", start_datetime: "2026-01-01 09:00", end_datetime: "2026-01-01 10:00")
    late = @universe.events.create!(title: "Late", start_datetime: "2026-01-01 11:00", end_datetime: "2026-01-01 12:00")

    layout = TimelineLayout.new([ early, late ])

    assert_equal [ [ early ], [ late ] ], layout.layers
  end

  test "orders events using start dates when ranges are unknown" do
    early = @universe.events.create!(title: "Early", start_datetime: "2026-01-01 09:00")
    late = @universe.events.create!(title: "Late", start_datetime: "2026-01-02 09:00")

    layout = TimelineLayout.new([ early, late ])

    assert_equal [ [ early ], [ late ] ], layout.layers
  end

  test "orders events using explicit before_event/after_event relations" do
    first = @universe.events.create!(title: "First")
    second = @universe.events.create!(title: "Second", before_event: first)

    layout = TimelineLayout.new([ first, second ])

    assert_equal [ [ second ], [ first ] ], layout.layers
  end

  test "groups simultaneous events on the same layer" do
    a = @universe.events.create!(title: "A")
    b = @universe.events.create!(title: "B", simultaneous_event: a)

    layout = TimelineLayout.new([ a, b ])

    assert_equal 1, layout.layers.length
    assert_equal [ a, b ].sort_by(&:id), layout.layers.first.sort_by(&:id)
  end

  test "no drawn edge points against the layer order" do
    early = @universe.events.create!(title: "Early", start_datetime: "2026-01-01 09:00")
    late = @universe.events.create!(title: "Late", start_datetime: "2026-01-05 09:00", before_event: early)

    layout = TimelineLayout.new([ early, late ])

    assert_equal [ [ early ], [ late ] ], layout.layers
    # `late` declares that it happens before `early`, but the dates order them
    # the other way and the dates are the stronger signal, so the layout put
    # `early` on top. The refused declaration must not be drawn as an arrow
    # running back up the page.
    assert_empty layout.edges
  end

  test "a relation the dates contradict is dropped, not silently reversed" do
    first = @universe.events.create!(title: "First", start_datetime: "2026-01-01 09:00")
    second = @universe.events.create!(title: "Second", start_datetime: "2026-01-02 09:00")

    # `first` declares that it happens after `second`, but its own date is the
    # earlier of the two, so the dates win and the arrow is refused.
    first.update!(after_event: second)
    layout = TimelineLayout.new([ first.reload, second ])

    assert_equal [ [ first ], [ second ] ], layout.layers
    assert_empty layout.edges
  end

  test "a relation the dates agree with is still drawn" do
    first = @universe.events.create!(title: "First", start_datetime: "2026-01-01 09:00")
    second = @universe.events.create!(title: "Second", start_datetime: "2026-01-02 09:00", after_event: first)

    layout = TimelineLayout.new([ first, second ])

    assert_equal [ [ first ], [ second ] ], layout.layers
    assert_equal [ { from: first.id, to: second.id, kind: "sequence" } ], layout.edges
  end

  test "a cycle between two relations is broken instead of drawn both ways" do
    a = @universe.events.create!(title: "A")
    b = @universe.events.create!(title: "B")
    a.update!(after_event: b)
    b.update!(after_event: a)

    layout = TimelineLayout.new([ a.reload, b.reload ])

    # One of the two declarations closed a cycle and was refused, so exactly one
    # arrow survives, and it runs from the higher row to the lower one.
    assert_equal 1, layout.edges.length
    edge = layout.edges.first
    assert_equal "sequence", edge[:kind]
    assert_operator row_of(layout, edge[:from]), :<, row_of(layout, edge[:to])
  end

  test "a simultaneous event that also declares a sequence relation draws only the simultaneous edge" do
    a = @universe.events.create!(title: "A")
    b = @universe.events.create!(title: "B", simultaneous_event: a, after_event: a)

    layout = TimelineLayout.new([ a.reload, b.reload ])

    assert_equal 1, layout.layers.length
    assert_equal [ { from: b.id, to: a.id, kind: "simultaneous" } ], layout.edges
  end

  test "one arrow is drawn for a relation named from both sides" do
    a = @universe.events.create!(title: "A")
    b = @universe.events.create!(title: "B", before_event: a)
    a.update!(after_event: b)

    layout = TimelineLayout.new([ a.reload, b.reload ])

    assert_equal [ { from: b.id, to: a.id, kind: "sequence" } ], layout.edges
  end

  test "edges never point at an event that is not in the layout" do
    reference = @universe.events.create!(title: "Reference")
    alone = @universe.events.create!(title: "Alone", before_event: reference)

    # A subset of the universe's events: the layout is handed `alone` alone, and
    # `reference` is not one of them, so it cannot be drawn or layered.
    layout = TimelineLayout.new([ alone ])

    assert_equal [ [ alone ] ], layout.layers
    assert_empty layout.edges
  end

  private

  # The row an event was placed on, so a test can assert an arrow's direction
  # against the layers the view renders.
  def row_of(layout, event_id)
    layout.layers.index { |layer| layer.any? { |event| event.id == event_id } }
  end
end
