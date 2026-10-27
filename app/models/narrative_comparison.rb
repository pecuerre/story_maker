# Compares a Story's narrative order with the Universe Timeline, without writing.
#
# `Scene.position` orders telling and `TimelineLayout` orders happening. They are
# different questions, so a reversal between them is not an error: it is a
# flashback, a parallel thread, or a cold open. The only thing this object calls a
# conflict is a **single Scene** whose own `datetime` falls outside the Event it
# links, because that is one Scene making two in-world claims that cannot both be
# true.
#
# A Scene's place comes from its linked Event's row in the layout and never from
# its own `datetime`. A Scene with no Event is unlinked; a Scene whose Event the
# Timeline cannot place is unsequenced; both end the current run, so the next
# placed Scene is the first in a new one. That is the whole of the comparison: it reads,
# it never moves a Scene, links an Event, changes a `datetime`, or resolves a
# disagreement.
class NarrativeComparison
  # One Scene in narrative order, with the place it can be given and the step
  # that place makes against the previous Scene in its run.
  Row = Data.define(:scene, :position, :event, :timeline_row, :step, :compared_scene, :conflict) do
    def placed?
      !timeline_row.nil?
    end

    def unlinked?
      event.nil?
    end

    # The Scene names an Event, but the Timeline has no recorded time for it.
    def unsequenced?
      !event.nil? && !placed?
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
      event = scene.event
      attributes = {
        scene: scene,
        position: scene.position + 1,
        event: event,
        conflict: conflict?(scene)
      }

      unless event.present? && layout.placed?(event)
        return Row.new(**attributes, timeline_row: nil, step: nil, compared_scene: nil)
      end

      timeline_row = timeline_row_for(event)
      step, compared_scene = step_for(previous, event, timeline_row)
      Row.new(**attributes, timeline_row: timeline_row, step: step, compared_scene: compared_scene)
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
        next if row.event.nil?

        (positions[row.event.id] ||= []) << row.position
      end
    end

    # The only conflict there is. The Event states the bounds; an absent bound is
    # open, a reversed range says nothing about the Scene, and a Scene without its
    # own time or without an Event has no second claim to disagree with.
    def conflict?(scene)
      event = scene.event
      return false if event.nil? || scene.datetime.nil?

      starts_at = event.start_datetime
      ends_at = event.end_datetime
      return false if starts_at.nil? && ends_at.nil?
      return false if starts_at && ends_at && ends_at < starts_at

      before_start = starts_at.present? && scene.datetime < starts_at
      after_end = ends_at.present? && scene.datetime > ends_at

      before_start || after_end
    end
end
