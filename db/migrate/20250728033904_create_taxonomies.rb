class CreateTaxonomies < ActiveRecord::Migration[8.0]
  def change
    create_table :taxonomies do |t|
      t.string :name
      t.text :description
      t.string :slug
      t.boolean :fixed

      t.timestamps
    end
  end
end
