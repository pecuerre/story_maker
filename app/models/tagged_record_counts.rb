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
# different query. The universe/story scope and the soft-delete exclusion both stay
# explicit filters on the element side — the same rules the association itself
# applies, restated because raw SQL does not inherit `default_scope`. All
# interpolated values go through `sanitize_sql_array`.
#
# The result maps tag id => tagged record count, so a taxonomy row can show a
# "(10 characters)" count pill without an N+1.
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

    <<~SQL.squish
      SELECT #{tag_id} AS #{tag_column}, #{count_sql_for(join_table, tag_column)} AS #{COUNT_ALIAS}
      FROM #{connection.quote_table_name(join_table)}
      WHERE #{tag_id} IN (?)
      #{scope_sql(element_class, reflection, tag_column, scope_column)}
      GROUP BY #{tag_id}
    SQL
  end
  private_class_method :count_sql

  # The HABTM table has neither a universe/story column nor a `deleted_at`, so both
  # are enforced on the element side, exactly like the instance-dependent
  # association scope. Tag ids are already universe/story specific, so the scope
  # filter only rules out a corrupt cross-scope join row rather than doing the
  # primary filtering.
  #
  # The `deleted_at IS NULL` predicate is the same kind of correction. This query is
  # raw SQL, so the element model's `default_scope` does not apply, and a soft
  # delete deliberately keeps both the row and its join-table rows so that a
  # restore is complete. Without it, deleting a tagged record left it counted in its
  # tags' `(N characters)` pills while being invisible everywhere else.
  def self.scope_sql(element_class, reflection, tag_column, scope_column)
    table = connection.quote_table_name(element_class.table_name)
    id = connection.quote_column_name(element_class.primary_key)
    element_id = connection.quote_column_name(element_foreign_key(reflection.join_table, tag_column))

    predicates = []
    predicates << "#{connection.quote_column_name(scope_column)} IN (?)" if scope_column.present?
    if element_class.column_names.include?("deleted_at")
      predicates << "#{connection.quote_column_name("deleted_at")} IS NULL"
    end
    where = predicates.any? ? " WHERE #{predicates.join(" AND ")}" : ""

    "AND #{element_id} IN (SELECT #{id} FROM #{table}#{where})"
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
