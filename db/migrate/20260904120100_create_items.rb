class CreateItems < ActiveRecord::Migration[8.1]
  def change
    create_table :items do |t|
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :items }
      t.references :story, null: false, foreign_key: true
      t.references :item_type, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :description

      t.timestamps
    end
  end
end