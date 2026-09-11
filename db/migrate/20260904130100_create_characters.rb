class CreateCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :characters do |t|
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :characters }
      t.references :story, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.text :description
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :characters, :character_types, table_name: :characters_character_types
  end
end
