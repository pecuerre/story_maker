class CreateRelations < ActiveRecord::Migration[8.1]
  def change
    create_table :relations do |t|
      t.references :story, null: false, foreign_key: true
      t.references :character1, null: false, foreign_key: { to_table: :characters }
      t.references :character2, null: false, foreign_key: { to_table: :characters }
      t.references :relation_type, null: false, foreign_key: true
      t.text :description
      t.datetime :from_date
      t.datetime :to_date

      t.timestamps
    end
  end
end
