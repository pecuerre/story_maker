# A tag with children is often a grouping for those children rather than a
# label a record can carry. `taggable` marks the distinction: a tag with
# `taggable: false` stays in the taxonomy tree and on records that already
# carry it, but it is not offered in an element's tag editor. Defaults to
# true so an ordinary tag is assignable unless it is explicitly a grouping.
class AddTaggableToTags < ActiveRecord::Migration[8.1]
  TAG_TABLES = %w[
    character_tags
    location_tags
    item_tags
    event_tags
    relation_tags
    ownership_tags
    section_tags
    scene_tags
  ].freeze

  def change
    TAG_TABLES.each do |table|
      add_column table, :taggable, :boolean, default: true, null: false
    end
  end
end
