require "test_helper"

class NarrativeChartLayoutTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = @universe.stories.create!(name: "Chart story")
  end

  test "the left column is narrative order and the right column is the timeline's order" do
    late = event("Late", start_datetime: "2026-01-01 10:00")
    early = event("Early", start_datetime: "2026-01-01 09:00")
    scene("Told first", position: 0, event: late)
    scene("Told second", position: 1, event: early)

    layout = layout_for(late, early)
    first, second = layout.entries

    # Narrative order is the entry order, and the bars are counted from the top.
    assert_equal [ 1, 2 ], layout.entries.map(&:position)
    assert_equal [ 6.0, 18.0 ], layout.entries.map(&:left_y)
    # The first-told Scene happens last, so its right-hand bar sits below the
    # second-told Scene's.
    assert_equal [ 18.0, 6.0 ], layout.entries.map(&:right_y)
    assert_operator first.right_y, :>, second.right_y
    # Each bar also knows its place in its own column, for its accessible name.
    assert_equal [ 2, 1 ], layout.entries.map(&:chronological_position)
  end

  test "a scene with no place on the timeline is drawn last, in narrative order" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")
    bare = event("Bare")
    scene("Placed", position: 0, event: dated)
    scene("Unlinked", position: 1)
    scene("Unsequenced", position: 2, event: bare)

    layout = layout_for(dated, bare)

    assert_equal 1, layout.placed_count
    assert_equal 2, layout.unplaced_count
    assert_equal 3, layout.entries.size
    assert_equal [ 1, 2, 3 ], layout.entries.map(&:position)
    # The dashed rule sits between the placed bars and the unplaced band.
    assert_equal 12.0, layout.separator_y
    assert_equal [ 18.0, 30.0 ], layout.entries.last(2).map(&:right_y)
  end

  test "an all-placed story has no separator rule" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")
    scene("Only", position: 0, event: dated)

    layout = layout_for(dated)

    assert_equal 0, layout.unplaced_count
    assert_nil layout.separator_y
  end

  test "a story is compressed towards one screen but never below the smallest bar" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")
    100.times { |index| scene("Scene #{index}", position: index, event: dated) }

    layout = layout_for(dated)

    assert_equal 5, layout.pitch
    assert_equal 500, layout.height
    assert_equal 2, layout.bar_height

    long_story = @universe.stories.create!(name: "Long story")
    200.times { |index| long_story.scenes.create!(name: "Long #{index}", position: index) }

    long_layout = NarrativeChartLayout.new(
      NarrativeComparison.new(scenes: long_story.scenes.order(:position, :id),
        layout: TimelineLayout.new([ dated ]))
    )

    assert_equal NarrativeChartLayout::MIN_PITCH, long_layout.pitch
    assert_equal NarrativeChartLayout::MIN_BAR_HEIGHT, long_layout.bar_height
  end

  test "a short story keeps roomy bars" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")
    scene("Only", position: 0, event: dated)

    layout = layout_for(dated)

    assert_equal NarrativeChartLayout::MAX_PITCH, layout.pitch
    assert_equal NarrativeChartLayout::MAX_PITCH - NarrativeChartLayout::BAR_INSET, layout.bar_height
    assert_equal NarrativeChartLayout::MAX_PITCH, layout.height
  end

  test "a connector leaves the left bar and arrives at the right one" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")
    scene("Only", position: 0, event: dated)

    entry = layout_for(dated).entries.first

    assert_equal "M 300.00 6.00 C 468.00 6.00, 532.00 6.00, 700.00 6.00", entry.connector
  end

  private
    def event(title, start_datetime: nil)
      @universe.events.create!(title: title, start_datetime: start_datetime)
    end

    def scene(name, position:, event: nil)
      scene = @story.scenes.create!(name: name, position: position)
      scene.scene_events.create!(event: event) if event
      scene
    end

    def layout_for(*events)
      NarrativeChartLayout.new(
        NarrativeComparison.new(
          scenes: @story.scenes.order(:position, :id),
          layout: TimelineLayout.new(events)
        )
      )
    end
end
