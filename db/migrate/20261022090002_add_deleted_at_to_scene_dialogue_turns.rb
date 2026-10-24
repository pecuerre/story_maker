# Item 9.A: turn-level dialogue.
#
# A turn soft-deletes like its Element: the row is kept and hidden by the
# default scope so a restore can bring it back into its sequence.
class AddDeletedAtToSceneDialogueTurns < ActiveRecord::Migration[8.1]
  def change
    add_column :scene_dialogue_turns, :deleted_at, :datetime
    add_index :scene_dialogue_turns, :deleted_at
  end
end
