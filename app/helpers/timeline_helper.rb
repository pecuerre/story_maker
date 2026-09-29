module TimelineHelper
  # The hover popover's title. An Event's own title is author-entered data and is
  # never translated; only the fallback for an Event that has none is chrome.
  def event_popover_title(event)
    event.title.presence || t("timeline.event_placeholder", id: event.id)
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
  # The relationship sentences ("before X") are whole translated sentences with
  # the related Event interpolated, rather than an English frame around a name:
  # their word order differs by language and cannot be assembled from fragments.
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
    related << h(t("timeline.popover.before", event: event.before_event.display_string)) if event.before_event
    related << h(t("timeline.popover.after", event: event.after_event.display_string)) if event.after_event
    related << h(t("timeline.popover.simultaneous", event: event.simultaneous_event.display_string)) if event.simultaneous_event
    parts << "<div><strong>#{h(t("timeline.popover.related"))}</strong> #{related.join(', ')}</div>" if related.any?

    parts << "<div>#{h(event.description)}</div>" if event.description.present?

    parts.join
  end
end
