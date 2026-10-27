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
end
