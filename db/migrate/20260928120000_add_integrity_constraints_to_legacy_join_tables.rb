# The seven legacy tag join tables were created with bare create_join_table and
# therefore lack the foreign keys and unique-pair index the Scene-era join tables
# already carry. Add them so duplicate or orphan join rows are rejected by the
# database itself instead of only by the scoped association reads.
class AddIntegrityConstraintsToLegacyJoinTables < ActiveRecord::Migration[8.1]
  JOIN_TABLES = {
    characters_character_tags: %i[ characters character_tags ].freeze,
    events_event_tags: %i[ events event_tags ].freeze,
    items_item_tags: %i[ items item_tags ].freeze,
    locations_location_tags: %i[ locations location_tags ].freeze,
    ownerships_ownership_tags: %i[ ownerships ownership_tags ].freeze,
    relations_relation_tags: %i[ relations relation_tags ].freeze,
    sections_section_tags: %i[ sections section_tags ].freeze
  }.freeze

  def change
    JOIN_TABLES.each do |join_table, (left, right)|
      add_foreign_key join_table, left
      add_foreign_key join_table, right

      left_column = "#{left.to_s.singularize}_id"
      right_column = "#{right.to_s.singularize}_id"
      # The conventional "index_<table>_on_<columns>" name exceeds SQLite's
      # 64-character index-name limit for these longer join table names.
      add_index join_table, [ left_column, right_column ], unique: true,
        name: "index_#{join_table}_unique"
    end
  end
end
