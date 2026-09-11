class ConvertElementTypesToManyToMany < ActiveRecord::Migration[8.1]
  PAIRS = {
    sections: { type_table: :section_types, fk: :section_type_id, join_table: :sections_section_types },
    characters: { type_table: :character_types, fk: :character_type_id, join_table: :characters_character_types },
    relations: { type_table: :relation_types, fk: :relation_type_id, join_table: :relations_relation_types },
    locations: { type_table: :location_types, fk: :location_type_id, join_table: :locations_location_types },
    events: { type_table: :event_types, fk: :event_type_id, join_table: :events_event_types },
    items: { type_table: :item_types, fk: :item_type_id, join_table: :items_item_types },
    ownerships: { type_table: :ownership_types, fk: :ownership_type_id, join_table: :ownerships_ownership_types }
  }.freeze

  def up
    PAIRS.each do |table, opts|
      element_id_column = "#{table.to_s.singularize}_id"
      type_id_column = "#{opts[:type_table].to_s.singularize}_id"

      create_join_table table, opts[:type_table], table_name: opts[:join_table] do |t|
        t.index [ element_id_column, type_id_column ], unique: true, name: "index_#{opts[:join_table]}_uniq"
        t.index [ type_id_column, element_id_column ], name: "index_#{opts[:join_table]}_inverse"
      end

      execute <<~SQL.squish
        INSERT INTO #{opts[:join_table]} (#{element_id_column}, #{type_id_column})
        SELECT id, #{opts[:fk]} FROM #{table} WHERE #{opts[:fk]} IS NOT NULL
      SQL

      remove_reference table, opts[:fk].to_s.sub(/_id\z/, ""), foreign_key: true
    end
  end

  def down
    PAIRS.each do |table, opts|
      fk_name = opts[:fk].to_s.sub(/_id\z/, "")
      element_id_column = "#{table.to_s.singularize}_id"
      type_id_column = "#{opts[:type_table].to_s.singularize}_id"

      add_reference table, fk_name, foreign_key: { to_table: opts[:type_table] }

      # Best-effort: a destroyed record may have had several types, only the lowest id survives the rollback.
      execute <<~SQL.squish
        UPDATE #{table}
        SET #{opts[:fk]} = (
          SELECT #{type_id_column} FROM #{opts[:join_table]}
          WHERE #{opts[:join_table]}.#{element_id_column} = #{table}.id
          ORDER BY #{type_id_column} LIMIT 1
        )
      SQL

      drop_join_table table, opts[:type_table], table_name: opts[:join_table]
    end
  end
end
