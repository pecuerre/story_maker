module TimelineHelper
  def event_popover_title(event)
    event.title.presence || "Event ##{event.id}"
  end

  # Builds the inner HTML for an event's hover popover. Returns a plain (non
  # html_safe) string so it gets escaped once more when written into the
  # data-bs-content attribute, and decoded back to real markup by the browser.
  def event_popover_content(event)
    parts = []

    if event.start_datetime.present? || event.end_datetime.present?
      dates = [ event.start_datetime, event.end_datetime ].compact.map { |d| d.strftime("%Y-%m-%d %H:%M") }.join(" &rarr; ")
      parts << "<div><strong>Dates:</strong> #{dates}</div>"
    end

    if event.event_type.present?
      parts << "<div><strong>Type:</strong> #{h(event.event_type.name)}</div>"
    end

    related = []
    related << "before #{h(event.before_event.display_string)}" if event.before_event
    related << "after #{h(event.after_event.display_string)}" if event.after_event
    related << "same time as #{h(event.simultaneous_event.display_string)}" if event.simultaneous_event
    parts << "<div><strong>Related:</strong> #{related.join(', ')}</div>" if related.any?

    parts << "<div>#{h(event.description)}</div>" if event.description.present?

    parts.join
  end
end
