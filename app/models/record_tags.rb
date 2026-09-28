# The tags carried by each record of a loaded collection, from one grouped query.
#
# A tag's details page lists the records that carry it and now shows every tag
# next to each record, not just the tag being viewed. The tag/element pairs
# declared by `HasManyTags` are HABTM associations with an instance-dependent
# scope, so Rails refuses to eager load or group through them (see
# `TaggedRecordCounts` for the same reason). Reading `record.<type>_tags` per
# row would add one query per listed record, so this value object reads the
# join table once for the whole list instead.
#
# Table and column names come from the record class and its `<Model>Tag`
# counterpart, so a renamed table cannot silently produce a different query.
# The query is wrapped in `sanitize_sql_array` with every identifier quoted,
# so it carries no untrusted text. The result maps record id => its tags
# ordered by name, so a tag page renders the same badges the record's own list
# rows show.
class RecordTags < ApplicationRecord
  self.abstract_class = true

  def self.for(records)
    return {} if records.empty?

    klass = records.first.class
    tag_class = "#{klass.name}Tag".constantize
    join_table = connection.quote_table_name("#{klass.table_name}_#{tag_class.table_name}")
    content_key = "#{klass.name.underscore}_id"
    tag_key = "#{tag_class.name.underscore}_id"
    quoted_content = connection.quote_column_name(content_key)
    quoted_tag = connection.quote_column_name(tag_key)

    sql = <<~SQL.squish
      SELECT #{quoted_content}, #{quoted_tag}
      FROM #{join_table}
      WHERE #{quoted_content} IN (?)
    SQL

    pairs = connection.select_all(sanitize_sql_array([ sql, records.map(&:id) ]))

    tags = tag_class.where(id: pairs.map { |row| row[tag_key] }).order(:name, :id).index_by(&:id)

    pairs.each_with_object({}) do |row, hash|
      (hash[row[content_key]] ||= []) << tags[row[tag_key]]
    end.transform_values { |list| list.sort_by { |tag| [ tag.name, tag.id ] } }
  end
end
