class AddShortSummaryToSections < ActiveRecord::Migration[8.1]
  def change
    add_column :sections, :short_summary, :text
  end
end
