class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :sections }
      t.references :universe, null: false, foreign_key: { to_table: :universes }
      t.integer :position, null: false, default: 0
      t.text :description
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :sections, :section_tags, table_name: :sections_section_tags
  end
end
