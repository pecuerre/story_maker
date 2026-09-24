class AddEventSelfReferenceChecks < ActiveRecord::Migration[8.1]
  def change
    add_check_constraint :events,
      "before_event_id IS NULL OR before_event_id <> id",
      name: "events_before_event_not_self"
    add_check_constraint :events,
      "after_event_id IS NULL OR after_event_id <> id",
      name: "events_after_event_not_self"
    add_check_constraint :events,
      "simultaneous_event_id IS NULL OR simultaneous_event_id <> id",
      name: "events_simultaneous_event_not_self"
  end
end
