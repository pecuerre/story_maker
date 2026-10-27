# Compares a Story's narrative order with the Universe Timeline, without writing.
#
# `Scene.position` orders telling and `TimelineLayout` orders happening. They are
# different questions, so a reversal between them is not an error: it is a
# flashback, a parallel thread, or a cold open. The only thing this object calls a
# conflict is a **single Scene** whose own `datetime` falls outside every Event it
# depicts, because that is one Scene making in-world claims that cannot all be
# true; a time inside any one of its Events is consistent with at least one.
#
# A Scene's place comes from the earliest placed Event it links, never from its own
# `datetime`; the link order breaks a tie between Events in the same Timeline row.
# A Scene with no Event is unlinked; a Scene whose Events the Timeline cannot place
# is unsequenced; both end the current run, so the next placed Scene is the first
# in a new one. That is the whole of the comparison: it reads, it never moves a
# Scene, links an Event, changes a `datetime`, or resolves a disagreement.
class NarrativeComparison
  # One Scene in narrative order, with the place it can be given and the step
  # that place makes against the previous Scene in its run.
  #
  # `events` is every Event the Scene depicts, in the Scene's own link order.
  # `event` is the one that places the Scene: the earliest linked Event the Timeline
  # can place, with the link order breaking a tie. It is nil when none is placed.
  Row = Data.define(:scene, :position, :events, :event, :timeline_row, :step, :compared_scene,
    :conflict, :conflict_events) do
    def placed?
      !timeline_row.nil?
    end

    def unlinked?
      events.empty?
    end

    # The Scene names Events, but the Timeline has no recorded time for any of them.
    def unsequenced?
      events.any? && !placed?
    end

    def conflict?
      conflict
    end
  end

  # One numbered row of the right-hand Timeline. Only layers holding at least one
  # placed Event are rendered; numbering is therefore compact rather than the raw
  # layer index.
  TimelineRow = Data.define(:number, :events)

  Summary = Data.define(:scenes, :placed, :unlinked, :unsequenced, :conflicts,
    :later, :earlier, :same_time, :unknown_order, :runs)

  attr_reader :layout

  def initialize(scenes:, layout:)
    # Narrative order is the contract, so this object owns it rather than trusting
    # the caller's relation order. A Scene's position is per Story and unique.
    @scenes = scenes.to_a.sort_by { |scene| [ scene.position, scene.id ] }
    @layout = layout
  end

  def rows
    @rows ||= build_rows
  end

  def summary
    @summary ||= Summary.new(
      scenes: rows.size,
      placed: rows.count(&:placed?),
      unlinked: rows.count(&:unlinked?),
      unsequenced: rows.count(&:unsequenced?),
      conflicts: rows.count(&:conflict?),
      later: rows.count { |row| row.step == :later },
      earlier: rows.count { |row| row.step == :earlier },
      same_time: rows.count { |row| row.step == :same_time },
      unknown_order: rows.count { |row| row.step == :unknown_order },
      runs: rows.count { |row| row.step == :first }
    )
  end

  # The Timeline's rows that have a placed Event. The layers themselves are the
  # layout's, so this cannot disagree with the Timeline page about order.
  def timeline_rows
    @timeline_rows ||= layout.layers.each_with_object([]) do |layer, rows|
      events = layer.select { |event| layout.placed?(event) }
      next if events.empty?

      rows << TimelineRow.new(number: rows.size + 1, events: events)
    end
  end

  # Events the Timeline cannot place. They are rendered apart from the numbered
  # rows instead of in the layout's arbitrary top row.
  def unplaced_events
    @unplaced_events ||= layout.events.reject { |event| layout.placed?(event) }
  end

  # The narrative positions of this Story's Scenes that depict one Event.
  def positions_for(event)
    positions_by_event_id.fetch(event.id, [])
  end

  private
    def build_rows
      previous = nil
      @scenes.map do |scene|
        row = build_row(scene, previous)
        previous = row.placed? ? row : nil
        row
      end
    end

    def build_row(scene, previous)
      events = scene_events_for(scene).map(&:event)
      placement = placement_for(events)
      attributes = {
        scene: scene,
        position: scene.position + 1,
        events: events,
        event: placement&.first,
        conflict: conflict?(scene, events),
        conflict_events: conflict_events(scene, events)
      }

      unless placement
        return Row.new(**attributes, timeline_row: nil, step: nil, compared_scene: nil)
      end

      timeline_row = placement.last
      step, compared_scene = step_for(previous, placement.first, timeline_row)
      Row.new(**attributes, timeline_row: timeline_row, step: step, compared_scene: compared_scene)
    end

    # A Scene's own links in the order the author put them. The loaded association
    # is sorted in memory rather than re-queried, so a page that preloaded the links
    # does not pay one query per Scene.
    def scene_events_for(scene)
      scene.scene_events.sort_by { |link| [ link.position, link.id ] }
    end

    # [ event, timeline row ] for the Event that places the Scene, or nil when the
    # Timeline can place none of the Scene's Events. The earliest row wins; the link
    # order decides between Events in the same row.
    def placement_for(events)
      events.each_with_index.filter_map do |event, index|
        row = timeline_row_for(event)
        next if row.nil?

        [ event, row, index ]
      end.min_by { |_event, row, index| [ row, index ] }&.first(2)
    end

    # A run is a maximal stretch of Scenes that all have a place. `previous` is
    # nil at the start of a run, so the first placed Scene says "First in this
    # run" and the comparison never guesses across a gap.
    def step_for(previous, event, timeline_row)
      return [ :first, nil ] if previous.nil?

      step =
        if timeline_row > previous.timeline_row
          :later
        elsif timeline_row < previous.timeline_row
          :earlier
        elsif layout.same_group?(previous.event, event)
          :same_time
        else
          :unknown_order
        end

      [ step, previous.scene ]
    end

    def timeline_row_for(event)
      timeline_row_numbers[event.id]
    end

    def timeline_row_numbers
      @timeline_row_numbers ||= timeline_rows.each_with_object({}) do |row, numbers|
        row.events.each { |event| numbers[event.id] = row.number }
      end
    end

    def positions_by_event_id
      @positions_by_event_id ||= rows.each_with_object({}) do |row, positions|
        row.events.each do |event|
          (positions[event.id] ||= []) << row.position
        end
      end
    end

    # The Events whose recorded interval the Scene's own time falls outside. A
    # Scene that links several Events may sit between two of them, so the conflict
    # is only when it is outside **every** claiming Event: a time inside any one of
    # them is consistent with at least one fact the Scene records.
    def conflict_events(scene, events)
      return [] if scene.datetime.nil?

      claiming = events.select { |event| claims_a_time?(event) }
      claiming.select { |event| outside_event?(scene.datetime, event) }
    end

    # The only conflict there is. The Events state the bounds; an absent bound is
    # open, a reversed range says nothing about the Scene, and a Scene without its
    # own time or without a claiming Event has no second claim to disagree with.
    def conflict?(scene, events)
      return false if scene.datetime.nil?

      claiming = events.select { |event| claims_a_time?(event) }
      claiming.any? && claiming.all? { |event| outside_event?(scene.datetime, event) }
    end

    def claims_a_time?(event)
      starts_at = event.start_datetime
      ends_at = event.end_datetime
      return false if starts_at.nil? && ends_at.nil?
      return false if starts_at && ends_at && ends_at < starts_at

      true
    end

    def outside_event?(datetime, event)
      before_start = event.start_datetime.present? && datetime < event.start_datetime
      after_end = event.end_datetime.present? && datetime > event.end_datetime

      before_start || after_end
    end
end
