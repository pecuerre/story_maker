class AddProfileFieldsToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :what_it_does, :text
    add_column :items, :how_it_is_used, :text
    add_column :items, :side_effects, :text
    add_column :items, :origin, :text
    add_column :items, :value, :text
    add_column :items, :cannot, :text
    add_column :items, :constraints, :text
    add_column :items, :history, :text
    add_column :items, :jargon, :text
  end
end
