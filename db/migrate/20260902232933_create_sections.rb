class CreateSections < ActiveRecord::Migration[8.1]
  def change
    create_table :sections do |t|
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :sections }
      t.references :story, null: false, foreign_key: { to_table: :stories }
      t.references :section_type, null: false, foreign_key: { to_table: :section_types }

      t.timestamps
    end
  end
end
