class CreatePlots < ActiveRecord::Migration[8.1]
  def change
    create_table :plots do |t|
      t.references :story, null: false, foreign_key: true
      t.string :name, null: false
      t.text :description
      t.string :slug, null: false
      t.datetime :deleted_at

      t.timestamps
    end

    add_index :plots, [ :story_id, :name ], unique: true,
      where: "deleted_at IS NULL", name: "index_plots_on_live_story_and_name"
    add_index :plots, [ :story_id, :slug ], unique: true,
      where: "deleted_at IS NULL", name: "index_plots_on_live_story_and_slug"
    add_index :plots, :deleted_at

    create_table :plots_scenes, id: false do |t|
      t.references :plot, null: false, foreign_key: true
      t.references :scene, null: false, foreign_key: true
    end

    add_index :plots_scenes, [ :plot_id, :scene_id ], unique: true,
      name: "index_plots_scenes_on_plot_id_and_scene_id"
  end
end
