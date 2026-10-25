class CreateFactionTags < ActiveRecord::Migration[8.1]
  def change
    create_table :faction_tags do |t|
      t.references :universe, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :slug, null: false
      t.references :parent, foreign_key: { to_table: :faction_tags }
      t.integer :position, null: false, default: 0
      t.string :bgcolor, null: false, default: "#d3d3d3"
      t.string :fgcolor, null: false, default: "#000000"
      t.boolean :taggable, null: false, default: true
      t.boolean :show_in_menu, null: false, default: false
      t.references :photo, foreign_key: { on_delete: :nullify }
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :faction_tags, :deleted_at
  end
end
