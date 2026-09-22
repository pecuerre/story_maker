class CreateLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :locations do |t|
      t.string :name
      t.references :parent, foreign_key: { to_table: :locations }
      t.text :description
      t.references :universe, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :locations, :location_tags, table_name: :locations_location_tags
  end
end