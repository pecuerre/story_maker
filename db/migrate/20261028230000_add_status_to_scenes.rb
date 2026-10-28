class AddStatusToScenes < ActiveRecord::Migration[8.1]
  def change
    add_column :scenes, :status, :string, null: false, default: "draft"
    add_check_constraint :scenes, "status IN ('draft', 'revised', 'final')", name: "scenes_status_is_known"
    add_index :scenes, [ :story_id, :status ]
  end
end
