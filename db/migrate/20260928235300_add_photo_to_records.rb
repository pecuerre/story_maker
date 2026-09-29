# Every record a reader can land on a details page for may carry one photo:
# the universe-level content records, the story-level ones, and all eight tag
# taxonomies, plus the Universe and Story workspaces themselves.
#
# The reference is always optional — `null: true` — because a photo is never
# required, and a record without one behaves exactly as it did before.
#
# `on_delete: :nullify` is deliberate and matches the existing deletion
# contract: a reference that exists only to name an image is cleared rather
# than cascaded, so removing a photo that is still pointed at degrades to "this
# record has no photo" instead of a foreign-key error. Normal uploads never
# share a photo between two records, so this is the safety net, not the path.
class AddPhotoToRecords < ActiveRecord::Migration[8.1]
  PHOTO_TABLES = %w[
    universes
    stories
    sections
    scenes
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
    section_tags
    scene_tags
  ].freeze

  def change
    PHOTO_TABLES.each do |table|
      add_reference table, :photo, null: true,
        foreign_key: { to_table: :photos, on_delete: :nullify }
    end
  end
end
