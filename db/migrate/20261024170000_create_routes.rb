class CreateRoutes < ActiveRecord::Migration[8.1]
  def change
    create_table :routes do |t|
      t.references :universe, null: false, foreign_key: true
      t.references :from_location, null: false, foreign_key: { to_table: :locations }
      t.references :to_location, null: false, foreign_key: { to_table: :locations }
      t.references :photo, foreign_key: true
      t.string :name
      t.text :description
      t.string :distance
      t.string :duration
      t.string :slug, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :routes, :deleted_at
    add_index :routes, [ :universe_id, :id ]
    add_index :routes, [ :from_location_id, :deleted_at ]
    add_index :routes, [ :to_location_id, :deleted_at ]
  end
end
