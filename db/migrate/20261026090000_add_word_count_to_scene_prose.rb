class AddWordCountToSceneProse < ActiveRecord::Migration[8.1]
  def change
    add_column :scene_elements, :word_count, :integer, default: 0, null: false
    add_column :scene_dialogue_turns, :word_count, :integer, default: 0, null: false
  end
end
