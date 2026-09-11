class CreateRelationTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :relation_types do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :relation_types }
      t.integer :position, null: false, default: 0
      t.text :description
      t.boolean :symmetric, null: false, default: true
      t.string :inverse
      t.string :slug, null: false
      t.string :color, null: false, default: "#d3d3d3"

      t.timestamps
    end
  end
end