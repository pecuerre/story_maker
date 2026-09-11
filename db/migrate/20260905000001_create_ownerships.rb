class CreateOwnerships < ActiveRecord::Migration[8.1]
  def change
    create_table :ownerships do |t|
      t.references :story, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      t.text :description
      t.string :name
      t.datetime :from_date
      t.datetime :to_date
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :ownerships, :ownership_types, table_name: :ownerships_ownership_types
  end
end
