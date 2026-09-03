class AddDescriptionToSectionTypes < ActiveRecord::Migration[8.1]
  def change
    add_column :section_types, :description, :text
  end
end