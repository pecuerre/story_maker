class AddColorToTaxonomyTypes < ActiveRecord::Migration[8.1]
  def change
    %i[ section_types character_types relation_types location_types item_types ownership_types ].each do |table|
      add_column table, :color, :string, null: false, default: "#d3d3d3"
    end
  end
end
