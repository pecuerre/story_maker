class AddShortSummaryToPlots < ActiveRecord::Migration[8.1]
  def change
    add_column :plots, :short_summary, :text
  end
end
