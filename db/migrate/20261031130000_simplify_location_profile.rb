# A Location keeps only the fields a reader needs at a glance: name, description,
# tags, and its place in the hierarchy. The nineteen structured profile answers
# (sensory, layout, significance, history, and access) are folded into one
# Markdown `description`, which carries its own `##` sections.
#
# Schema-only, as ADR 0003 requires: the disposable development data in
# `db/data/` is where the demo prose is reloaded from.
class SimplifyLocationProfile < ActiveRecord::Migration[8.1]
  def change
    remove_column :locations, :sensory_sight, :text
    remove_column :locations, :sensory_sound, :text
    remove_column :locations, :sensory_smell, :text
    remove_column :locations, :sensory_taste, :text
    remove_column :locations, :sensory_touch, :text

    remove_column :locations, :layout_structure, :text
    remove_column :locations, :layout_key_areas, :text
    remove_column :locations, :layout_pathways, :text
    remove_column :locations, :layout_entrances_exits, :text
    remove_column :locations, :layout_points_of_interest, :text

    remove_column :locations, :significance, :text

    remove_column :locations, :history_significant_events, :text
    remove_column :locations, :history_past_occupants, :text
    remove_column :locations, :history_changes, :text

    remove_column :locations, :access_controlled_by, :text
    remove_column :locations, :access_granted_how, :text
    remove_column :locations, :access_security, :text
    remove_column :locations, :access_restrictions, :text
  end
end
