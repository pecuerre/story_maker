class CreateOwnershipTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :ownership_types do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.references :parent, foreign_key: { to_table: :ownership_types }
      t.integer :position, null: false, default: 0

      t.timestamps
    end
  end
end
