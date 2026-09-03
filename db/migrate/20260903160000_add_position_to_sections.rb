class AddPositionToSections < ActiveRecord::Migration[8.1]
  def up
    add_column :sections, :position, :integer

    Section.reset_column_information
    positions = Hash.new(0)

    Section.order(:story_id, :parent_id, :id).find_each do |section|
      key = [ section.story_id, section.parent_id ]
      section.update_columns(position: positions[key])
      positions[key] += 1
    end

    change_column_default :sections, :position, 0
    change_column_null :sections, :position, false
  end

  def down
    remove_column :sections, :position
  end
end