class Event < ApplicationRecord
  # A validation runs wherever a record is saved, not only inside a request, so the
  # three `errors.add` messages below resolve their keys through `I18n.t` rather
  # than through a view/controller `t`. A save from a console, a job, or the
  # development-data loader has the default locale, so those callers get the
  # English message — exactly what they got before, because the message was a
  # literal.
  include Hierarchical
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesMenuCounts
  include Searchable
  include HasDiscussion

  searchable kind: "event", title: :name, body: :description, route: "event"
  invalidates_menu_counts_for :universe
  soft_deletes :children

  belongs_to :universe
  has_many_tags :event_tag, scope: :universe_id
  # Deleting an Event only clears Scene references. The shared world record is
  # never removed because a Scene depicted it, and the Scene keeps its own
  # narrative position and (independent) in-world datetime.
  has_many :scenes, dependent: :nullify
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

  validate :temporal_references_exist
  validate :associated_records_belong_to_universe
  validate :cannot_reference_self
  validate :must_be_identifiable

  # A short label for this event, falling back to its known relations when it has no title or dates.
  #
  # This is the **stored** form. `Event` indexes `name` rather than this label, so
  # nothing here reaches the index — but `Relation` and `Ownership` make the same
  # kind of label their `searchable title:`, and one index serves every reader, so
  # the rule is written once for all three: the stored form is resolved in the
  # application's default locale, whatever the request is in. A document written by
  # a Spanish request must not carry Spanish chrome for the next reader.
  #
  # A view reads `#display_label`, which is the same ladder in the reader's
  # language. `EventTest` holds the *stored* wording, so it cannot move without the
  # test saying so.
  def display_string(visited = [])
    I18n.with_locale(AppLocale::DEFAULT) { display_label(visited) }
  end

  # The same label, in the reader's language. The four phrases are chrome and the
  # event's own title, dates, and id are data, so a chain of relationships reads
  # as a chain of translated sentences: a referenced event's label is itself one.
  def display_label(visited = [])
    return I18n.t("events.display_label.unidentified", id: id) if visited.include?(self)
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
      I18n.t("events.display_label.before", event: before_event.display_label(visited))
    elsif after_event.present?
      I18n.t("events.display_label.after", event: after_event.display_label(visited))
    elsif simultaneous_event.present?
      I18n.t("events.display_label.simultaneous", event: simultaneous_event.display_label(visited))
    else
      I18n.t("events.display_label.unidentified", id: id)
    end
  end

  private

  # A soft-deleted Event leaves every referrer in place but clears the
  # references, exactly like a hard delete: Scenes lose their `event_id`, and
  # temporal referrers lose the `before_event_id`/`after_event_id`/
  # `simultaneous_event_id` that pointed here. A referrer that was only
  # identifiable through this Event keeps its row and reports the missing
  # identifier the next time it is saved, rather than being destroyed.
  def soft_delete_dependencies
    scenes.update_all(event_id: nil)
    before_event_references.update_all(before_event_id: nil)
    after_event_references.update_all(after_event_id: nil)
    simultaneous_event_references.update_all(simultaneous_event_id: nil)
  end

  def set_name
    self.name = title if new_record? || will_save_change_to_title?
  end

  def formatted_datetime(datetime)
    datetime.strftime("%Y-%m-%d %H:%M")
  end

  # The three temporal references are optional, so an id that names no Event
  # resolves to `nil` and the write would be refused by the database's foreign key
  # — an unhandled 500 instead of the documented error hash. `Hierarchical`'s
  # `parent_reference_exists` is the same rule for a parent; this is its Event
  # equivalent, and `Scene#optional_references_exist` is the third.
  #
  # It runs before `associated_records_belong_to_universe` and `must_be_identifiable`
  # so an unknown id is reported on the field that carried it. An unknown
  # reference also leaves the Event with nothing to identify it by, so a
  # reference-only Event legitimately collects both messages.
  def temporal_references_exist
    temporal_references.each_key do |name|
      next unless public_send("#{name}_id").present? && public_send(name).nil?

      errors.add(name, I18n.t("events.errors.must_exist"))
    end
  end

  # The three temporal associations in one place, because three rules read them
  # and a fourth association would otherwise have to be added to all three.
  def temporal_references
    { before_event: before_event, after_event: after_event, simultaneous_event: simultaneous_event }
  end

  def associated_records_belong_to_universe
    temporal_references.each do |name, record|
      next unless record && universe && record.universe_id != universe_id

      errors.add(name, I18n.t("events.errors.must_belong_to_universe"))
    end
  end

  def cannot_reference_self
    temporal_references.each do |name, record|
      foreign_key = public_send("#{name}_id")
      next unless record == self || (id.present? && foreign_key.present? && foreign_key == id)

      errors.add(name, I18n.t("events.errors.cannot_be_itself"))
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

    errors.add(:base, I18n.t("events.errors.must_be_identifiable"))
  end
end
