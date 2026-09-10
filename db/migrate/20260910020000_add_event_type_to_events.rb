class AddEventTypeToEvents < ActiveRecord::Migration[8.1]
  def change
    add_reference :events, :event_type, null: true, foreign_key: true
  end
end
