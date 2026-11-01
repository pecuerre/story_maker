class AddSummaryToItems < ActiveRecord::Migration[8.1]
  def change
    add_column :items, :summary, :text
  end
end
