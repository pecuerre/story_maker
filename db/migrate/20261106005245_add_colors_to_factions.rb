class AddColorsToFactions < ActiveRecord::Migration[8.1]
  def change
    add_column :factions, :bgcolor, :string, null: false, default: "#d3d3d3"
    add_column :factions, :fgcolor, :string, null: false, default: "#000000"
  end
end
