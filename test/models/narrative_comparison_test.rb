require "test_helper"

class NarrativeComparisonTest < ActiveSupport::TestCase
  setup do
    @universe = universes(:universe_one)
    @story = @universe.stories.create!(name: "Comparison story")
  end

  test "labels every step inside one run" do
    early = event("Early", start_datetime: "2026-01-01 09:00")
    late = event("Late", start_datetime: "2026-01-01 10:00")
    same_a = event("Same A", start_datetime: "2026-01-01 09:00")
    same_b = event("Same B", start_datetime: "2026-01-01 09:00")

    scene("First", position: 0, event: early)
    scene("Second", position: 1, event: late)
    scene("Third", position: 2, event: early)
    scene("Fourth", position: 3, event: late)
    scene("Fifth", position: 4, event: same_a)
    scene("Sixth", position: 5, event: same_b)
    scene("Seventh", position: 6, event: same_b)

    comparison = comparison_for(early, late, same_a, same_b)

    assert_equal %i[first later earlier later earlier unknown_order same_time],
      comparison.rows.map(&:step)
    assert_equal [ 1, 2, 1, 2, 1, 1, 1 ], comparison.rows.map(&:timeline_row)
    assert_equal [ 1, 2, 3, 4, 5, 6, 7 ], comparison.rows.map(&:position)
    assert_equal [ 1, 2 ], comparison.timeline_rows.map(&:number)
    assert_equal [ 1, 3 ], comparison.positions_for(early)
    assert_equal [ 6, 7 ], comparison.positions_for(same_b)
    assert_empty comparison.unplaced_events

    summary = comparison.summary
    assert_equal 7, summary.scenes
    assert_equal 7, summary.placed
    assert_equal 0, summary.unlinked
    assert_equal 0, summary.unsequenced
    assert_equal 0, summary.conflicts
    assert_equal 2, summary.later
    assert_equal 2, summary.earlier
    assert_equal 1, summary.same_time
    assert_equal 1, summary.unknown_order
    assert_equal 1, summary.runs
  end

  test "an unlinked scene ends the run and the next placed scene starts a new one" do
    early = event("Early", start_datetime: "2026-01-01 09:00")
    late = event("Late", start_datetime: "2026-01-01 10:00")

    scene("First", position: 0, event: early)
    scene("Gap", position: 1, datetime: "2026-01-01 09:30")
    scene("Resume", position: 2, event: late)
    scene("Return", position: 3, event: early)

    comparison = comparison_for(early, late)

    assert_equal [ :first, nil, :first, :earlier ], comparison.rows.map(&:step)
    assert comparison.rows[1].unlinked?
    refute comparison.rows[1].placed?
    assert_equal 1, comparison.summary.unlinked
    assert_equal 2, comparison.summary.runs
  end

  test "an event with no recorded time is unsequenced and ends the run" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")
    bare = event("Bare")

    scene("First", position: 0, event: dated)
    scene("Gap", position: 1, event: bare)
    scene("Resume", position: 2, event: dated)

    comparison = comparison_for(dated, bare)

    assert_equal [ :first, nil, :first ], comparison.rows.map(&:step)
    assert comparison.rows[1].unsequenced?
    refute comparison.rows[1].placed?
    assert_equal [ bare ], comparison.unplaced_events
    assert_equal [ 1 ], comparison.timeline_rows.map(&:number)
    assert_equal 1, comparison.summary.unsequenced
    assert_equal 2, comparison.summary.runs
  end

  test "a conflict is only a scene's own time outside its event's interval" do
    meeting = event("Meeting", start_datetime: "2026-01-01 09:00", end_datetime: "2026-01-01 10:00")

    scene("Before", position: 0, event: meeting, datetime: "2026-01-01 08:59")
    scene("At start", position: 1, event: meeting, datetime: "2026-01-01 09:00")
    scene("Inside", position: 2, event: meeting, datetime: "2026-01-01 09:30")
    scene("At end", position: 3, event: meeting, datetime: "2026-01-01 10:00")
    scene("After", position: 4, event: meeting, datetime: "2026-01-01 10:01")

    comparison = comparison_for(meeting)

    assert_equal [ true, false, false, false, true ], comparison.rows.map(&:conflict?)
    assert_equal 2, comparison.summary.conflicts
  end

  test "a one-sided event bounds only the side it records" do
    start_only = event("Start only", start_datetime: "2026-01-01 09:00")
    end_only = event("End only", end_datetime: "2026-01-01 10:00")

    scene("Before start", position: 0, event: start_only, datetime: "2026-01-01 08:00")
    scene("After start", position: 1, event: start_only, datetime: "2026-01-01 11:00")
    scene("Before end", position: 2, event: end_only, datetime: "2026-01-01 09:00")
    scene("After end", position: 3, event: end_only, datetime: "2026-01-01 11:00")

    comparison = comparison_for(start_only, end_only)

    assert_equal [ true, false, false, true ], comparison.rows.map(&:conflict?)
  end

  test "a reversed event range makes no claim about the scene" do
    reversed = event("Reversed", start_datetime: "2026-01-01 10:00", end_datetime: "2026-01-01 11:00")
    reversed.update_column(:end_datetime, Time.zone.parse("2026-01-01 09:00"))

    scene("Outside", position: 0, event: reversed.reload, datetime: "2026-01-01 08:00")

    comparison = comparison_for(reversed)

    refute comparison.rows.first.conflict?
  end

  test "an unlinked scene is not placed by its datetime and cannot conflict" do
    dated = event("Dated", start_datetime: "2026-01-01 09:00")

    scene("By event", position: 0, event: dated, datetime: "1990-01-01 09:00")
    scene("Own time only", position: 1, datetime: "2026-01-01 09:00")

    comparison = comparison_for(dated)

    assert comparison.rows[0].placed?
    assert_equal 1, comparison.rows[0].timeline_row
    assert comparison.rows[1].unlinked?
    refute comparison.rows[1].placed?
    refute comparison.rows[1].conflict?
  end

  test "rows follow narrative order rather than the order the scenes arrive in" do
    first, second = [ scene("First", position: 0), scene("Second", position: 1) ]
    reversed = NarrativeComparison.new(
      scenes: @story.scenes.order(position: :desc),
      layout: TimelineLayout.new([])
    )

    assert_equal [ first.id, second.id ], reversed.rows.map { |row| row.scene.id }
    assert_equal 0, reversed.summary.placed
    assert_equal 2, reversed.summary.unlinked
  end

  private
    def event(title, start_datetime: nil, end_datetime: nil, **attributes)
      @universe.events.create!(title: title, start_datetime: start_datetime,
        end_datetime: end_datetime, **attributes)
    end

    def scene(name, position:, event: nil, datetime: nil)
      @story.scenes.create!(name: name, position: position, event: event, datetime: datetime)
    end

    def comparison_for(*events)
      NarrativeComparison.new(
        scenes: @story.scenes.order(:position, :id),
        layout: TimelineLayout.new(events)
      )
    end
end
