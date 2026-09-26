# Slice 11.7: explicit Character presence in a Scene.
#
# This is a join model rather than a plain HABTM association because the role is
# part of the decision: it is a nullable free-text annotation that the author
# maintains, never a controlled vocabulary the application interprets.
class CreateSceneCharacters < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_characters do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
      # Blank means no role. It is not validated against any vocabulary.
      t.string :role

      t.timestamps
    end

    add_index :scene_characters, [ :scene_id, :character_id ], unique: true,
      name: "index_scene_characters_on_scene_id_and_character_id"
  end
end
