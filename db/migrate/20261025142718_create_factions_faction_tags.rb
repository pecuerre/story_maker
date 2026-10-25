class CreateFactionsFactionTags < ActiveRecord::Migration[8.1]
  def change
    create_join_table :factions, :faction_tags, table_name: :factions_faction_tags
    add_index :factions_faction_tags, [ :faction_id, :faction_tag_id ], unique: true
    add_foreign_key :factions_faction_tags, :factions
    add_foreign_key :factions_faction_tags, :faction_tags
  end
end
