class CreateOwnershipsAndOwnershipTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :ownership_types do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.references :parent, foreign_key: { to_table: :ownership_types }
      t.integer :position, null: false, default: 0

      t.timestamps
    end

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
