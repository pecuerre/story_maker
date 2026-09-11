class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :items }
      t.references :story, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :description
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :items, :item_types, table_name: :items_item_types
  end
end