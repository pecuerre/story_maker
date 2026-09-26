# Slice 11.6: Scene Elements and the many-to-many Dialogue speaker link.
#
# An Element is one flat ordered block of a Scene's prose. `kind` is restricted
# rather than a `type` column, because Active Record reserves `type` for
# single-table inheritance. The speaker link is a plain many-to-many join
# because it carries no data of its own and implies no turn order.
class CreateSceneElements < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_elements do |t|
      t.references :scene, null: false, foreign_key: true
      t.string :kind, null: false, default: "narration"
      t.string :name
      t.text :body
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # The Element sequence is contiguous within its own Scene and independent of
    # the Scene's narrative position in its Story.
    add_index :scene_elements, [ :scene_id, :position ]
    add_check_constraint :scene_elements, "kind IN ('narration', 'dialogue')",
      name: "scene_elements_kind_is_known"

    create_table :scene_element_speakers, id: false do |t|
      t.references :scene_element, null: false, foreign_key: true
      t.references :character, null: false, foreign_key: true
    end

    add_index :scene_element_speakers, [ :scene_element_id, :character_id ], unique: true,
      name: "index_scene_element_speakers_on_element_and_character"
  end
end
