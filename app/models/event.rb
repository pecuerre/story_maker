class Event < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  has_many_tags :event_tag, scope: :universe_id
  belongs_to :before_event, class_name: "Event", inverse_of: :before_event_references, optional: true
  belongs_to :after_event, class_name: "Event", inverse_of: :after_event_references, optional: true
  belongs_to :simultaneous_event, class_name: "Event", inverse_of: :simultaneous_event_references, optional: true
  before_destroy :destroy_unidentifiable_temporal_referrers
  has_many :before_event_references,
    class_name: "Event",
    foreign_key: :before_event_id,
    inverse_of: :before_event,
    dependent: :nullify
  has_many :after_event_references,
    class_name: "Event",
    foreign_key: :after_event_id,
    inverse_of: :after_event,
    dependent: :nullify
  has_many :simultaneous_event_references,
    class_name: "Event",
    foreign_key: :simultaneous_event_id,
    inverse_of: :simultaneous_event,
    dependent: :nullify
  # Run before HasSlug so a newly created event without an explicit slug can derive it from the title.
  before_validation :set_name, prepend: true

  validate :associated_records_belong_to_universe
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

  def set_name
    self.name = title if new_record? || will_save_change_to_title?
  end

  def formatted_datetime(datetime)
    datetime.strftime("%Y-%m-%d %H:%M")
  end

  def associated_records_belong_to_universe
    { before_event: before_event, after_event: after_event, simultaneous_event: simultaneous_event }.each do |name, record|
      errors.add(name, "must belong to the event's universe") if record && universe && record.universe_id != universe_id
    end
  end

  def cannot_reference_self
    { before_event: before_event, after_event: after_event, simultaneous_event: simultaneous_event }.each do |name, record|
      foreign_key = public_send("#{name}_id")
      next unless record == self || (id.present? && foreign_key.present? && foreign_key == id)

      errors.add(name, "cannot be itself")
    end
  end

  def destroy_unidentifiable_temporal_referrers
    @destroying_temporal_referrers = true
    temporal_referrers.each do |referrer|
      next if referrer.id == id || referrer.instance_variable_get(:@destroying_temporal_referrers) ||
        referrer.send(:identifiable_without_temporal_reference?, id)

      referrer.destroy!
    end
  ensure
    remove_instance_variable(:@destroying_temporal_referrers) if defined?(@destroying_temporal_referrers)
  end

  def temporal_referrers
    (before_event_references.to_a + after_event_references.to_a + simultaneous_event_references.to_a).uniq
  end

  def identifiable_without_temporal_reference?(event_id)
    return true if title.present? || start_datetime.present? || end_datetime.present?

    %i[before_event_id after_event_id simultaneous_event_id].any? do |name|
      foreign_key = public_send(name)
      foreign_key.present? && foreign_key != event_id
    end
  end

  def must_be_identifiable
    return if title.present? || start_datetime.present? || end_datetime.present? ||
      before_event.present? || after_event.present? || simultaneous_event.present?

    errors.add(:base, "must have a title, a date, or a relation to another event")
  end
end
