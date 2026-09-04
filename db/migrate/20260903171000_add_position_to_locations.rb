class AddPositionToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :position, :integer, null: false, default: 0
  end
end
