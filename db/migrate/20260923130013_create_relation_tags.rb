class CreateRelationTags < ActiveRecord::Migration[8.1]
  def change
    create_table :relation_tags do |t|
      t.references :universe, null: false, foreign_key: true
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :relation_tags }
      t.integer :position, null: false, default: 0
      t.text :description
      t.boolean :symmetric, null: false, default: true
      t.string :inverse
      t.string :slug, null: false
      t.string :bgcolor, null: false, default: "#d3d3d3"
      t.string :fgcolor, null: false, default: "#000000" # black

      t.timestamps
    end
  end
end
