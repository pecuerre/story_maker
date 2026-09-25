# How many records carry each tag in a taxonomy, from one grouped query.
#
# The tag/element pairs declared by `HasManyTags` are HABTM associations with an
# instance-dependent scope (`->(owner) { where(universe_id: owner.universe_id) }`),
# so Rails refuses to eager load or group through them ("Eager loading instance
# dependent scopes is not supported"). Counting per tag would add one query per
# tree row, so this value object groups the HABTM table in a single query instead.
#
# Every table and column name comes from the association's own reflection or from
# the live schema, so a renamed table or column cannot silently produce a
# different query, and the universe/story scope stays an explicit filter — the same
# rule the association itself applies. All interpolated values go through
# `sanitize_sql_array`.
#
# The result maps tag id => tagged record count, so a taxonomy row can show
# "Details (10 characters)" without an N+1.
class TaggedRecordCounts < ApplicationRecord
  self.abstract_class = true

  SCOPE_COLUMNS = %w[universe_id story_id].freeze
  COUNT_ALIAS = "record_count"

  # `records` is the taxonomy's own scope: a universe's tags, or one story's
  # story-scoped tags. The returned hash has one entry per tag, including zeros.
  def self.for(records)
    tag_ids = records.pluck(:id)
    return {} if tag_ids.empty?

    tag_model = records.model
    element_class = tag_model.name.delete_suffix("Tag").constantize
    reflection = tag_model.reflect_on_association(element_class.model_name.plural)
    return {} if reflection.nil?

    counts = fetch_counts(records, element_class, reflection, tag_ids)
    tag_ids.index_with { |tag_id| counts.fetch(tag_id, 0) }
  end

  def self.fetch_counts(records, element_class, reflection, tag_ids)
    tag_column = reflection.foreign_key
    scope_column = (element_class.column_names & SCOPE_COLUMNS).first
    scope_values = scope_column ? records.distinct.pluck(scope_column) : []

    statement = sanitize_sql_array(
      [ count_sql(element_class, reflection, tag_column, scope_column), tag_ids, scope_values ]
    )
    rows = connection.select_all(statement).index_by { |row| Integer(row[tag_column]) }

    rows.transform_values { |row| Integer(row.fetch(COUNT_ALIAS)) }
  end
  private_class_method :fetch_counts

  def self.count_sql(element_class, reflection, tag_column, scope_column)
    join_table = reflection.join_table
    tag_id = connection.quote_column_name(tag_column)
    scope = scope_column.present? ? scope_sql(element_class, reflection, tag_column, scope_column) : ""

    <<~SQL.squish
      SELECT #{tag_id} AS #{tag_column}, #{count_sql_for(join_table, tag_column)} AS #{COUNT_ALIAS}
      FROM #{connection.quote_table_name(join_table)}
      WHERE #{tag_id} IN (?)
      #{scope}
      GROUP BY #{tag_id}
    SQL
  end
  private_class_method :count_sql

  # The HABTM table has no universe/story column, so the shared scope is enforced
  # on the element side, exactly like the instance-dependent association scope. Tag
  # ids are already universe/story specific, so this only rules out a corrupt
  # cross-scope join row rather than doing the primary filtering.
  def self.scope_sql(element_class, reflection, tag_column, scope_column)
    table = connection.quote_table_name(element_class.table_name)
    id = connection.quote_column_name(element_class.primary_key)
    scope = connection.quote_column_name(scope_column)
    element_id = connection.quote_column_name(element_foreign_key(reflection.join_table, tag_column))

    <<~SQL.squish
      AND #{element_id} IN (SELECT #{id} FROM #{table} WHERE #{scope} IN (?))
    SQL
  end
  private_class_method :scope_sql

  # Counting the join table's element column rather than `*` ignores an orphaned
  # row whose element id is null, which the legacy join tables have no constraint
  # to prevent.
  def self.count_sql_for(join_table, tag_column)
    column = element_foreign_key(join_table, tag_column)
    return "COUNT(*)" if column.nil?

    "COUNT(#{connection.quote_table_name(join_table)}.#{connection.quote_column_name(column)})"
  end
  private_class_method :count_sql_for

  def self.element_foreign_key(join_table, tag_column)
    columns = connection.columns(join_table).map(&:name) - [ tag_column ]
    return columns.first if columns.one?

    nil
  end
  private_class_method :element_foreign_key
end
