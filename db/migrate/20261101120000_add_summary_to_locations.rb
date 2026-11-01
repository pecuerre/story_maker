# A Location gains the one-line short summary Characters and Factions already
# carry, shown in the tree and at the top of the details page. The full profile
# remains the Markdown `description`; this column is the glance a reader gets
# before opening the record.
#
# Schema-only, as ADR 0003 requires: the demo prose is reloaded from `db/data/`.
class AddSummaryToLocations < ActiveRecord::Migration[8.1]
  def change
    add_column :locations, :summary, :text
  end
end
