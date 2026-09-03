class AddPositionToSectionTypes < ActiveRecord::Migration[8.1]
  def up
    add_column :section_types, :position, :integer

    SectionType.reset_column_information
    positions = Hash.new(0)
    SectionType.order(:story_id, :parent_id, :id).find_each do |section_type|
      key = [ section_type.story_id, section_type.parent_id ]
      section_type.update_columns(position: positions[key])
      positions[key] += 1
    end

    change_column_default :section_types, :position, 0
    change_column_null :section_types, :position, false
  end

  def down
    remove_column :section_types, :position
  end
end