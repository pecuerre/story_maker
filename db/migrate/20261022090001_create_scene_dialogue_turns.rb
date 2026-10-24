# Item 9.A: turn-level dialogue.
#
# A turn is one spoken line inside a Dialogue Scene Element: who speaks (a
# same-Universe Character), the line itself, and an optional parenthetical, in a
# flat contiguous position inside its own Element. A turn is a component of its
# Element — it has no URL of its own — so there is no `parent_id` and no
# `universe_id`: the Universe is reached through `scene_element -> scene -> story`.
class CreateSceneDialogueTurns < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_dialogue_turns do |t|
      t.references :scene_element, null: false, foreign_key: true
      t.references :speaker, null: false, foreign_key: { to_table: :characters }
      t.text :body
      t.text :parenthetical
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    # The turn sequence is contiguous within its own Dialogue Element.
    add_index :scene_dialogue_turns, [ :scene_element_id, :position ]
  end
end
