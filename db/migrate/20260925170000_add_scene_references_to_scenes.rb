# Slice 11.2/11.3 Scene references and in-world time.
#
# `scenes` already shipped its create migration in slice 11.1, so these columns
# arrive as a separate schema-only alter migration. Editing the create migration
# would not work: Rails 8.1's `initialize_database` loads db/schema.rb when the
# database has no schema_migrations table, so an amended create migration is
# never executed on a freshly created database.
class AddSceneReferencesToScenes < ActiveRecord::Migration[8.1]
  def change
    # Optional organizational grouping. Section never expresses narrative order.
    add_reference :scenes, :section, null: true, foreign_key: true
    # Optional shared in-world fact. Several scenes may reference one event.
    add_reference :scenes, :event, null: true, foreign_key: true
    # One optional in-world time point, with the same storage as the event
    # datetimes. It is independent of the event reference and is deliberately
    # not an event start/end pair.
    add_column :scenes, :datetime, :datetime

    # Section-grouped lookup, kept beside the narrative-order index.
    add_index :scenes, [ :story_id, :section_id ]
  end
end
