class CreateRelations < ActiveRecord::Migration[8.1]
  def change
    create_table :relations do |t|
      t.references :universe, null: false, foreign_key: true
      t.references :character1, null: false, foreign_key: { to_table: :characters }
      t.references :character2, null: false, foreign_key: { to_table: :characters }
      t.string :name
      t.text :description
      t.datetime :from_date
      t.datetime :to_date
      t.string :slug, null: false

      t.timestamps
    end

    create_join_table :relations, :relation_types, table_name: :relations_relation_types
  end
end
