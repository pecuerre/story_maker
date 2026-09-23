class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :sections }
      t.integer :position, null: false, default: 0
      t.text :description
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :sections, :section_tags, table_name: :sections_section_tags
  end
end
