module NarrativeOrdersHelper
  # The step badge keeps its meaning in the text, so the border is only a second,
  # optional cue. A colour on its own would not say which step it is.
  STEP_BORDER_CLASSES = {
    first: "border-secondary",
    later: "border-success",
    earlier: "border-warning",
    same_time: "border-info",
    unknown_order: "border-secondary"
  }.freeze

  def narrative_step_border_class(step)
    STEP_BORDER_CLASSES.fetch(step, "border-secondary")
  end

  # An Event is named by its title where it has one. The `display_label` ladder is
  # the fallback for an Event identified only by a date or a relation, and it is
  # the same label Event details and the Timeline's popover use.
  def narrative_event_label(event)
    event.title.presence || event.display_label
  end

  # The one sentence a conflicting row prints. A Scene that links one claiming
  # Event keeps the precise range; one that links several says which Events it is
  # outside of, because a single range could not describe a point that lies between
  # two of them.
  def narrative_conflict_message(row)
    events = row.conflict_events

    if events.one?
      event = events.first
      t("narrative_orders.conflict",
        time: scene_in_world_time(row.scene),
        range: in_world_range(event.start_datetime, event.end_datetime))
    else
      t("narrative_orders.conflict_multiple",
        time: scene_in_world_time(row.scene),
        events: events.map { |event| narrative_event_label(event) }.to_sentence)
    end
  end
end
