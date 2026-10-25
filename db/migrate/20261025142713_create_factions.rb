class CreateFactions < ActiveRecord::Migration[8.1]
  def change
    create_table :factions do |t|
      t.references :universe, null: false, foreign_key: true
      t.string :name
      t.string :slug, null: false
      t.text :mission
      t.text :actual_aims
      t.text :structure
      t.text :internal_divisions
      t.text :resources
      t.text :would_never
      t.text :would_absolutely
      t.references :photo, foreign_key: { on_delete: :nullify }
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :factions, :deleted_at
  end
end
