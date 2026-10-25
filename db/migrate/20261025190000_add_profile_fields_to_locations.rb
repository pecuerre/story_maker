class AddProfileFieldsToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :sensory_sight, :text
    add_column :locations, :sensory_sound, :text
    add_column :locations, :sensory_smell, :text
    add_column :locations, :sensory_taste, :text
    add_column :locations, :sensory_touch, :text

    add_column :locations, :layout_structure, :text
    add_column :locations, :layout_key_areas, :text
    add_column :locations, :layout_pathways, :text
    add_column :locations, :layout_entrances_exits, :text
    add_column :locations, :layout_points_of_interest, :text

    add_column :locations, :significance, :text

    add_column :locations, :history_significant_events, :text
    add_column :locations, :history_past_occupants, :text
    add_column :locations, :history_changes, :text

    add_column :locations, :access_controlled_by, :text
    add_column :locations, :access_granted_how, :text
    add_column :locations, :access_security, :text
    add_column :locations, :access_restrictions, :text
  end
end
