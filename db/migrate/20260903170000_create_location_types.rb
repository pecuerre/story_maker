class CreateLocationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :location_types do |t|
      t.string :name
      t.references :parent, foreign_key: { to_table: :location_types }
      t.integer :position, null: false, default: 0
      t.text :description
      t.references :universe, null: false, foreign_key: true
      t.string :slug, null: false
      t.string :bgcolor, null: false, default: "#d3d3d3"
      t.string :fgcolor, null: false, default: "#000000" # black

      t.timestamps
    end
  end
end