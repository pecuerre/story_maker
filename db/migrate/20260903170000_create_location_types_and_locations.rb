class CreateLocationTypesAndLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :location_types do |t|
      t.string :name
      t.references :parent, foreign_key: { to_table: :location_types }
      t.integer :position, null: false, default: 0
      t.text :description
      t.references :story, null: false, foreign_key: true

      t.timestamps
    end

    create_table :locations do |t|
      t.string :name
      t.references :parent, foreign_key: { to_table: :locations }
      t.text :description
      t.references :story, null: false, foreign_key: true
      t.references :location_type, null: false, foreign_key: true

      t.timestamps
    end
  end
end
