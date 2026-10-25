class AddCharacterProfileFactionsAndKnowledge < ActiveRecord::Migration[8.1]
  def change
    rename_column :characters, :description, :at_a_glance
    add_column :characters, :wants, :text
    add_column :characters, :needs, :text
    add_column :characters, :lies_to_self, :text
    add_column :characters, :contradictions, :text
    add_column :characters, :under_pressure_they, :text
    add_column :characters, :never, :text

    create_join_table :characters, :factions, table_name: :characters_factions do |t|
      t.foreign_key :characters
      t.foreign_key :factions
      t.index [ :character_id, :faction_id ], unique: true, name: "index_characters_factions_unique"
    end

    create_table :character_knowledges do |t|
      t.references :universe, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.references :source_character, foreign_key: { to_table: :characters }
      t.string :when_text
      t.text :what_learned
      t.boolean :changes_plan, null: false, default: false
      t.datetime :deleted_at
      t.timestamps
    end

    add_index :character_knowledges, :deleted_at
    add_index :character_knowledges, [ :character_id, :created_at ]
  end
end
