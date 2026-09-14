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
end
