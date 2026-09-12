class CreateSectionTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :section_types do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :section_types }
      t.integer :position, null: false, default: 0
      t.text :description
      t.string :bgcolor, null: false, default: "#d3d3d3"
      t.string :fgcolor, null: false, default: "#000000" # black
      t.string :slug, null: false

      t.timestamps
    end
  end
end
