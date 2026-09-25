# Scene tags are story-scoped taxonomy definitions. The association is kept
# separate from Section tags so a Story can label its scenes independently of
# its organizational sections.
class CreateSceneTags < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_tags do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name
      t.references :parent, null: true, foreign_key: { to_table: :scene_tags }
      t.integer :position, null: false, default: 0
      t.text :description
      t.string :bgcolor, null: false, default: "#d3d3d3"
      t.string :fgcolor, null: false, default: "#000000" # black
      t.string :slug, null: false

      t.timestamps
    end

    create_table :scenes_scene_tags, id: false do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :scene_tag, null: false, foreign_key: true
    end

    add_index :scenes_scene_tags, [ :scene_id, :scene_tag_id ], unique: true,
      name: "index_scenes_scene_tags_on_scene_id_and_scene_tag_id"
  end
end
