module TimelineHelper
  # The hover popover's title. An Event's own title is author-entered data and is
  # never translated; only the fallback for an Event that has none is chrome, and
  # that fallback is the same one `Event#display_label` uses, so a node and an
  # Event's own page cannot name an unnamed event differently.
  def event_popover_title(event)
    event.title.presence || t("events.display_label.unidentified", id: event.id)
  end

  # The node's accessible name. The node itself renders only the record's id,
  # which a screen reader would announce as a bare number, so the label names the
  # Event the popover describes. It is built from the same `event_popover_title`
  # the popover header uses, so the two can never describe different events.
  def event_node_aria_label(event)
    t("timeline.node_aria_label", event: event_popover_title(event))
  end

  # Builds the inner HTML for an event's hover popover. Returns a plain (non
  # html_safe) string so it gets escaped once more when written into the
  # data-bs-content attribute, and decoded back to real markup by the browser.
  #
  # The relationship sentences ("before X") come from `Event#display_label`'s own
  # phrases, with the related Event's own label interpolated: their word order
  # differs by language and cannot be assembled from fragments, and a second copy
  # of them here would be a second answer to what "before" means. The sentence
  # stays a sentence rather than becoming a labelled row, because the direction is
  # what this line is for and a label beside the name says it less directly.
  def event_popover_content(event)
    parts = []

    if event.start_datetime.present? || event.end_datetime.present?
      dates = [ event.start_datetime, event.end_datetime ].compact.map { |d| d.strftime("%Y-%m-%d %H:%M") }.join(" &rarr; ")
      parts << "<div><strong>#{h(t("timeline.popover.dates"))}</strong> #{dates}</div>"
    end

    if event.event_tags.any?
      parts << "<div><strong>#{h(t("timeline.popover.tag"))}</strong> #{h(event.event_tags.map(&:name).join(', '))}</div>"
    end

    related = []
    related << h(t("events.display_label.before", event: event.before_event.display_label)) if event.before_event
    related << h(t("events.display_label.after", event: event.after_event.display_label)) if event.after_event
    related << h(t("events.display_label.simultaneous", event: event.simultaneous_event.display_label)) if event.simultaneous_event
    parts << "<div><strong>#{h(t("timeline.popover.related"))}</strong> #{related.join(', ')}</div>" if related.any?

    parts << "<div>#{h(event.description)}</div>" if event.description.present?

    parts.join
  end
end
