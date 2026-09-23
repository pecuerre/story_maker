class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.references :universe, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.string :slug, null: false

      t.timestamps
    end

    add_index :stories, [ :universe_id, :slug ], unique: true
  end
end
