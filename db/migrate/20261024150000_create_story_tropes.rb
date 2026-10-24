class CreateStoryTropes < ActiveRecord::Migration[8.1]
  def change
    create_table :story_tropes do |t|
      t.references :story, null: false, foreign_key: true
      t.string :trope_slug, null: false
      t.text :context_note

      t.timestamps
    end

    add_index :story_tropes, [ :story_id, :trope_slug ], unique: true
  end
end
