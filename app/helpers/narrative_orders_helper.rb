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

  # A chart bar carries no visible text, so its accessible name is the label a
  # reader would otherwise have to hover for. A left bar names the Scene's
  # narrative position; a right bar names its chronological position where it has
  # one, because the two columns are two readings of the same Scene. A Scene the
  # Timeline cannot place keeps its narrative position in both columns and says it
  # has no place instead.
  def narrative_chart_node_label(entry, column:, total:)
    position =
      if column == :chronological && entry.placed?
        t("narrative_orders.chart.chronological_position_aria",
          position: entry.chronological_position, total: total)
      else
        t("shared.scene_position_aria", position: entry.position, total: total)
      end

    if entry.placed?
      t("narrative_orders.chart.node_label",
        position: position,
        name: entry.scene.name,
        step: t("narrative_orders.steps.#{entry.row.step}.label"))
    else
      t("narrative_orders.chart.node_label_unplaced",
        position: position,
        name: entry.scene.name)
    end
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
