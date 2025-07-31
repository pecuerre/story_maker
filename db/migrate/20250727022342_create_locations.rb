class CreateLocations < ActiveRecord::Migration[8.0]
  def change
    create_table :locations do |t|
      t.string :name
      t.text :description
      t.references :story, null: false, foreign_key: true
      t.integer :parent_id

      t.timestamps
    end
  end
end
