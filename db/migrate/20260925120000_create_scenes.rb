class CreateScenes < ActiveRecord::Migration[8.1]
  def change
    create_table :scenes do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.text :description
      t.integer :position, null: false, default: 0
      t.string :slug, null: false

      t.timestamps
    end

    add_index :scenes, [ :story_id, :position ]
  end
end
