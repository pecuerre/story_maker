class Event < ApplicationRecord
  include Hierarchical

  belongs_to :story
  belongs_to :before_event, class_name: "Event", optional: true
  belongs_to :after_event, class_name: "Event", optional: true
  belongs_to :simultaneous_event, class_name: "Event", optional: true

  validate :associated_records_belong_to_story
  validate :cannot_reference_self
  validate :must_be_identifiable

  # A short label for this event, falling back to its known relations when it has no title or dates.
  def display_string(visited = [])
    return "Event ##{id}" if visited.include?(self)
    visited = visited + [ self ]

    if title.present? && start_datetime.present?
      "#{title} - #{formatted_datetime(start_datetime)}"
    elsif title.present?
      title
    elsif start_datetime.present?
      formatted_datetime(start_datetime)
    elsif end_datetime.present?
      formatted_datetime(end_datetime)
    elsif before_event.present?
      "before #{before_event.display_string(visited)}"
    elsif after_event.present?
      "after #{after_event.display_string(visited)}"
    elsif simultaneous_event.present?
      "same time as #{simultaneous_event.display_string(visited)}"
    else
      "Event ##{id}"
    end
  end

  private

  def formatted_datetime(datetime)
    datetime.strftime("%Y-%m-%d %H:%M")
  end

  def associated_records_belong_to_story
    { before_event: before_event, after_event: after_event, simultaneous_event: simultaneous_event }.each do |name, record|
      errors.add(name, "must belong to the event's story") if record && story && record.story_id != story_id
    end
  end

  def cannot_reference_self
    errors.add(:before_event, "cannot be itself") if before_event_id.present? && before_event_id == id
    errors.add(:after_event, "cannot be itself") if after_event_id.present? && after_event_id == id
    errors.add(:simultaneous_event, "cannot be itself") if simultaneous_event_id.present? && simultaneous_event_id == id
  end

  def must_be_identifiable
    return if title.present? || start_datetime.present? || end_datetime.present? ||
      before_event.present? || after_event.present? || simultaneous_event.present?

    errors.add(:base, "must have a title, a date, or a relation to another event")
  end
end
