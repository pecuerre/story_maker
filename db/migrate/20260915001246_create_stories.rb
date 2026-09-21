class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.references :universe, null: false, foreign_key: { to_table: :universes }
      t.string :name
      t.text :description

      t.timestamps
    end
  end
end
