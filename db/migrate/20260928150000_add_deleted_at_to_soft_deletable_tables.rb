# Soft delete: a delete marks the record with `deleted_at` instead of removing
# the row, so the data survives and can be restored. Every content table that
# has a user-facing delete action carries the column.
#
# The unique indexes that would otherwise block re-creating a record with the
# same key after a soft delete are converted to partial indexes
# (`WHERE deleted_at IS NULL`), so a soft-deleted row no longer occupies the
# key. The matching model validations carry the same condition.
class AddDeletedAtToSoftDeletableTables < ActiveRecord::Migration[8.1]
  TABLES = %w[
    universes
    universe_memberships
    stories
    sections
    section_tags
    scene_tags
    scenes
    scene_elements
    scene_characters
    scene_items
    scene_locations
    characters
    locations
    items
    events
    relations
    ownerships
    character_tags
    location_tags
    item_tags
    event_tags
    relation_tags
    ownership_tags
  ].freeze

  def up
    TABLES.each do |table|
      add_column table, :deleted_at, :datetime
    end

    # A soft-deleted row must not occupy a unique key, so re-creating a record
    # with the same slug, membership, or presence link stays possible.
    remove_index :universes, name: "index_universes_on_slug"
    add_index :universes, :slug, unique: true, where: "deleted_at IS NULL", name: "index_universes_on_slug"

    remove_index :stories, name: "index_stories_on_universe_id_and_slug"
    add_index :stories, [ :universe_id, :slug ], unique: true, where: "deleted_at IS NULL",
      name: "index_stories_on_universe_id_and_slug"

    remove_index :universe_memberships, name: "index_universe_memberships_on_universe_id_and_user_id"
    add_index :universe_memberships, [ :universe_id, :user_id ], unique: true, where: "deleted_at IS NULL",
      name: "index_universe_memberships_on_universe_id_and_user_id"

    remove_index :scene_characters, name: "index_scene_characters_on_scene_id_and_character_id"
    add_index :scene_characters, [ :scene_id, :character_id ], unique: true, where: "deleted_at IS NULL",
      name: "index_scene_characters_on_scene_id_and_character_id"

    remove_index :scene_items, name: "index_scene_items_on_scene_id_and_item_id"
    add_index :scene_items, [ :scene_id, :item_id ], unique: true, where: "deleted_at IS NULL",
      name: "index_scene_items_on_scene_id_and_item_id"

    remove_index :scene_locations, name: "index_scene_locations_on_scene_id_and_location_id"
    add_index :scene_locations, [ :scene_id, :location_id ], unique: true, where: "deleted_at IS NULL",
      name: "index_scene_locations_on_scene_id_and_location_id"
  end

  def down
    remove_index :scene_locations, name: "index_scene_locations_on_scene_id_and_location_id"
    add_index :scene_locations, [ :scene_id, :location_id ], unique: true,
      name: "index_scene_locations_on_scene_id_and_location_id"

    remove_index :scene_items, name: "index_scene_items_on_scene_id_and_item_id"
    add_index :scene_items, [ :scene_id, :item_id ], unique: true,
      name: "index_scene_items_on_scene_id_and_item_id"

    remove_index :scene_characters, name: "index_scene_characters_on_scene_id_and_character_id"
    add_index :scene_characters, [ :scene_id, :character_id ], unique: true,
      name: "index_scene_characters_on_scene_id_and_character_id"

    remove_index :universe_memberships, name: "index_universe_memberships_on_universe_id_and_user_id"
    add_index :universe_memberships, [ :universe_id, :user_id ], unique: true,
      name: "index_universe_memberships_on_universe_id_and_user_id"

    remove_index :stories, name: "index_stories_on_universe_id_and_slug"
    add_index :stories, [ :universe_id, :slug ], unique: true,
      name: "index_stories_on_universe_id_and_slug"

    remove_index :universes, name: "index_universes_on_slug"
    add_index :universes, :slug, unique: true, name: "index_universes_on_slug"

    TABLES.each do |table|
      remove_column table, :deleted_at
    end
  end
end
