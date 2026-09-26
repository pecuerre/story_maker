# Slice 11.9: explicit Location presence in a Scene.
#
# This is a join model rather than a plain HABTM association because the role is
# part of the decision: it is a nullable free-text annotation that the author
# maintains, never a controlled vocabulary the application interprets. A Scene
# may use any number of Locations, which is why its workspace tab is plural.
class CreateSceneLocations < ActiveRecord::Migration[8.1]
  def change
    create_table :scene_locations do |t|
      t.references :scene, null: false, foreign_key: true
      t.references :location, null: false, foreign_key: true
      # Blank means no role. It is not validated against any vocabulary.
      t.string :role

      t.timestamps
    end

    add_index :scene_locations, [ :scene_id, :location_id ], unique: true,
      name: "index_scene_locations_on_scene_id_and_location_id"
  end
end
