class AddStoryAssociationToTaxonomies < ActiveRecord::Migration[8.0]
  def change
    add_reference :taxonomies, :story, null: true, foreign_key: true
    add_column :taxonomies, :story_taxonomy, :boolean, default: false
    add_column :taxonomies, :setting_taxonomy, :boolean, default: false
  end
end
