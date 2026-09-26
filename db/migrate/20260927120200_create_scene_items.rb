# Slice 11.8: explicit Item presence in a Scene.
#
# This is a join model rather than a plain HABTM association because the role is
# part of the decision: it is a nullable free-text annotation that the author
# maintains, never a controlled vocabulary the application interprets. An Item
# belongs to the Universe and is shared by every Story, so the link records that
# one Story's Scene happens to use it rather than copying the Item.
class CreateSceneItems < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_items do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :item, null: false, foreign_key: true
      # Blank means no role. It is not validated against any vocabulary.
      t.string :role

      t.timestamps
    end

    add_index :scene_items, [ :scene_id, :item_id ], unique: true,
      name: "index_scene_items_on_scene_id_and_item_id"
  end
end
