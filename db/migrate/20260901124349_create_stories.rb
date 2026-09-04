class CreateStories < ActiveRecord::Migration[8.1]
  def change
    create_table :stories do |t|
      t.string :name
      t.references :owner, null: false, foreign_key: { to_table: :users }
      t.boolean :private, default: false
      t.string :slug

      t.timestamps
    end
  end
end
