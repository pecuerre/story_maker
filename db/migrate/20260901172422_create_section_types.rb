class CreateSectionTypes < ActiveRecord::Migration[8.1]
  def change
    create_table :section_types do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :section_types }
      t.integer :position, null: false, default: 0
      t.text :description

      t.timestamps
    end
  end
end
