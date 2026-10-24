class CreateSceneTropes < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_tropes do |t|
      t.references :scene, null: false, foreign_key: true
      t.string :trope_slug, null: false
      t.text :context_note

      t.timestamps
    end

    add_index :scene_tropes, [ :scene_id, :trope_slug ], unique: true
  end
end
