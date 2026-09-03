class AddDescriptionToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :description, :text
  end
end
