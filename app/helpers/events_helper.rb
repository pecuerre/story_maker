module EventsHelper
  # "Label: value" descriptions of the filters currently in effect, in the order
  # the search area lists them. The result set of a large universe is otherwise
  # ambiguous, and an empty result has to be able to say what caused it.
  #
  # Each entry is its own key rather than one frame with the field name
  # interpolated, because "In-world from 2026-09-11" is a different sentence in
  # each language than "Section: <path>" is.
  #
  # The sort is described rather than omitted because a reader who reordered the
  # list and got nothing back needs to know that the order was applied and was
  # not the reason the list is short.
  def event_filter_summaries(filter)
    summaries = []
    summaries << t("events.filter.summaries.search", value: filter.text) if filter.text.present?
    if filter.event_tag
      summaries << t("events.filter.summaries.tag", value: @event_tag_paths.label_for(filter.event_tag))
    end
    summaries << t("events.filter.summaries.from", value: filter.from_date.iso8601) if filter.from_date
    summaries << t("events.filter.summaries.to", value: filter.to_date.iso8601) if filter.to_date
    summaries << t("events.filter.summaries.sort", value: t("events.filter.sort_options.#{filter.sort}")) if filter.sort != EventFilter::DEFAULT_SORT
    summaries
  end

  # The tag options the filter's selector offers, in root-first order. Built from
  # the paths rather than the flat query order so a child cannot appear before
  # its parent after a reparent or position edit.
  def event_filter_tag_choices
    @event_tag_paths.choices
  end

  # The events this event stands in time with, as a sentence for a list row:
  # `before The beginning, after The end` or `same time as The middle`. Reuses
  # `display_label` for each referenced event and the existing
  # `events.display_label.before/after/simultaneous` phrases. No new source
  # fields: the three temporal references already exist, only the presentation
  # changes.
  def event_related_events(event)
    related = []
    related << t("events.display_label.before", event: event.before_event.display_label) if event.before_event.present?
    related << t("events.display_label.after", event: event.after_event.display_label) if event.after_event.present?
    related << t("events.display_label.simultaneous", event: event.simultaneous_event.display_label) if event.simultaneous_event.present?
    related.to_sentence
  end
end
