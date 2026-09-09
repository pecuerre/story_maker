class CreateOwnerships < ActiveRecord::Migration[8.1]
  def change
    create_table :ownerships do |t|
      t.references :story, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.references :ownership_type, null: false, foreign_key: true
      t.text :description
      t.datetime :from_date
      t.datetime :to_date

      t.timestamps
    end
  end
end
