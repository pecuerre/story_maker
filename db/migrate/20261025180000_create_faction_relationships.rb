class CreateFactionRelationships < ActiveRecord::Migration[8.1]
  def change
    create_table :faction_relationships do |t|
      t.references :universe, null: false, foreign_key: true
      t.references :from_faction, null: false, foreign_key: { to_table: :factions }
      t.references :to_faction, null: false, foreign_key: { to_table: :factions }
      t.string :name
      t.text :description
      t.datetime :from_date
      t.datetime :to_date
      t.string :slug, null: false
      t.references :photo, foreign_key: { on_delete: :nullify }
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :faction_relationships, :deleted_at
  end
end
