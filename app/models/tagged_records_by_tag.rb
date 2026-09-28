# The records carried by each tag in one sibling group, read in a fixed number
# of queries. HasManyTags associations have instance-dependent scope lambdas,
# so they cannot be eager loaded; querying `tagged_records` for every child tag
# would otherwise add one query per child.
class TaggedRecordsByTag < ApplicationRecord
  self.abstract_class = true

  SCOPE_COLUMNS = %w[universe_id story_id].freeze

  # Returns a hash of tag id => records. Empty groups are included so callers
  # can render an honest empty state for a child that has no assignments.
  def self.for(tags)
    return {} if tags.empty?

    tag_class = tags.first.class
    association = tag_class.tagged_records_association
    reflection = tag_class.reflect_on_association(association)
    return tags.to_h { |tag| [ tag.id, [] ] } unless reflection

    tag_ids = tags.map(&:id)
    scope_column = tag_class.tagged_records_scope_attribute.to_s
    return tags.to_h { |tag| [ tag.id, [] ] } unless SCOPE_COLUMNS.include?(scope_column)

    scope_values = tags.map { |tag| tag.public_send(scope_column) }.uniq
    pairs = fetch_pairs(tag_class, reflection, scope_column, tag_ids, scope_values)
    element_class = reflection.klass
    element_ids = pairs.map { |row| row.fetch(reflection.association_foreign_key) }.uniq
    records = element_class.where(id: element_ids, scope_column => scope_values).order(:name, :id).index_by(&:id)
    grouped_ids = pairs.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |row, grouped|
      tag_id = Integer(row.fetch(reflection.foreign_key))
      record_id = Integer(row.fetch(reflection.association_foreign_key))
      grouped[tag_id] << record_id
    end

    tags.to_h do |tag|
      child_records = grouped_ids.fetch(tag.id, []).uniq.filter_map { |id| records[id] }
      [ tag.id, child_records.sort_by { |record| [ record.name, record.id ] } ]
    end
  end

  def self.fetch_pairs(tag_class, reflection, scope_column, tag_ids, scope_values)
    connection = tag_class.connection
    join_table = connection.quote_table_name(reflection.join_table)
    element_table = connection.quote_table_name(reflection.klass.table_name)
    tag_key = connection.quote_column_name(reflection.foreign_key)
    element_key = connection.quote_column_name(reflection.association_foreign_key)
    element_id = connection.quote_column_name(reflection.klass.primary_key)
    element_scope = connection.quote_column_name(scope_column)

    sql = <<~SQL.squish
      SELECT #{join_table}.#{tag_key}, #{join_table}.#{element_key}
      FROM #{join_table}
      INNER JOIN #{element_table}
        ON #{element_table}.#{element_id} = #{join_table}.#{element_key}
      WHERE #{join_table}.#{tag_key} IN (?)
        AND #{element_table}.#{element_scope} IN (?)
    SQL

    connection.select_all(tag_class.sanitize_sql_array([ sql, tag_ids, scope_values ]))
  end
  private_class_method :fetch_pairs
end
