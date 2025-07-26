class CreateLocationTypes < ActiveRecord::Migration[8.0]
  def change
    create_table :location_types do |t|
      t.string :name
      t.text :description
      t.references :story, null: false, foreign_key: true

      t.timestamps
    end
  end
end
