class AddDefaultToTaxonomiesFixed < ActiveRecord::Migration[8.0]
  def change
    change_column_default :taxonomies, :fixed, from: nil, to: false
  end
end
