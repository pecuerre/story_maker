class CreateTaxonomies < ActiveRecord::Migration[8.0]
  def change
    create_table :taxonomies do |t|
      t.string :name
      t.text :description
      t.string :slug
      t.boolean :fixed, default: false
      t.references :story, foreign_key: true
      t.boolean :is_story_taxonomy, default: false
      t.boolean :is_setting_taxonomy, default: false
      t.string :default_taxon, default: nil

      t.timestamps
    end
  end
end
