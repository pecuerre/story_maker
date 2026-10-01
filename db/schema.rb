# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_01_120000) do
  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "character_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.boolean "show_in_menu", default: false, null: false
    t.string "slug", null: false
    t.boolean "taggable", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_character_tags_on_parent_id"
    t.index ["photo_id"], name: "index_character_tags_on_photo_id"
    t.index ["universe_id"], name: "index_character_tags_on_universe_id"
  end

  create_table "characters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_characters_on_parent_id"
    t.index ["photo_id"], name: "index_characters_on_photo_id"
    t.index ["universe_id"], name: "index_characters_on_universe_id"
  end

  create_table "characters_character_tags", id: false, force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "character_tag_id", null: false
    t.index ["character_id", "character_tag_id"], name: "index_characters_character_tags_unique", unique: true
  end

  create_table "event_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.boolean "show_in_menu", default: false, null: false
    t.string "slug", null: false
    t.boolean "taggable", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_event_tags_on_parent_id"
    t.index ["photo_id"], name: "index_event_tags_on_photo_id"
    t.index ["universe_id"], name: "index_event_tags_on_universe_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "after_event_id"
    t.integer "before_event_id"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "end_datetime"
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.integer "simultaneous_event_id"
    t.string "slug", null: false
    t.datetime "start_datetime"
    t.string "title"
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["after_event_id"], name: "index_events_on_after_event_id"
    t.index ["before_event_id"], name: "index_events_on_before_event_id"
    t.index ["parent_id"], name: "index_events_on_parent_id"
    t.index ["photo_id"], name: "index_events_on_photo_id"
    t.index ["simultaneous_event_id"], name: "index_events_on_simultaneous_event_id"
    t.index ["universe_id"], name: "index_events_on_universe_id"
    t.check_constraint "after_event_id IS NULL OR after_event_id <> id", name: "events_after_event_not_self"
    t.check_constraint "before_event_id IS NULL OR before_event_id <> id", name: "events_before_event_not_self"
    t.check_constraint "simultaneous_event_id IS NULL OR simultaneous_event_id <> id", name: "events_simultaneous_event_not_self"
  end

  create_table "events_event_tags", id: false, force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "event_tag_id", null: false
    t.index ["event_id", "event_tag_id"], name: "index_events_event_tags_unique", unique: true
  end

  create_table "item_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.boolean "show_in_menu", default: false, null: false
    t.string "slug", null: false
    t.boolean "taggable", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_item_tags_on_parent_id"
    t.index ["photo_id"], name: "index_item_tags_on_photo_id"
    t.index ["universe_id"], name: "index_item_tags_on_universe_id"
  end

  create_table "items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_items_on_parent_id"
    t.index ["photo_id"], name: "index_items_on_photo_id"
    t.index ["universe_id"], name: "index_items_on_universe_id"
  end

  create_table "items_item_tags", id: false, force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "item_tag_id", null: false
    t.index ["item_id", "item_tag_id"], name: "index_items_item_tags_unique", unique: true
  end

  create_table "location_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.boolean "show_in_menu", default: false, null: false
    t.string "slug", null: false
    t.boolean "taggable", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_location_tags_on_parent_id"
    t.index ["photo_id"], name: "index_location_tags_on_photo_id"
    t.index ["universe_id"], name: "index_location_tags_on_universe_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_locations_on_parent_id"
    t.index ["photo_id"], name: "index_locations_on_photo_id"
    t.index ["universe_id"], name: "index_locations_on_universe_id"
  end

  create_table "locations_location_tags", id: false, force: :cascade do |t|
    t.integer "location_id", null: false
    t.integer "location_tag_id", null: false
    t.index ["location_id", "location_tag_id"], name: "index_locations_location_tags_unique", unique: true
  end

  create_table "ownership_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.boolean "taggable", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_ownership_tags_on_parent_id"
    t.index ["photo_id"], name: "index_ownership_tags_on_photo_id"
    t.index ["universe_id"], name: "index_ownership_tags_on_universe_id"
  end

  create_table "ownerships", force: :cascade do |t|
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "from_date"
    t.integer "item_id", null: false
    t.string "name"
    t.integer "photo_id"
    t.string "slug", null: false
    t.datetime "to_date"
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_ownerships_on_character_id"
    t.index ["item_id"], name: "index_ownerships_on_item_id"
    t.index ["photo_id"], name: "index_ownerships_on_photo_id"
    t.index ["universe_id"], name: "index_ownerships_on_universe_id"
  end

  create_table "ownerships_ownership_tags", id: false, force: :cascade do |t|
    t.integer "ownership_id", null: false
    t.integer "ownership_tag_id", null: false
    t.index ["ownership_id", "ownership_tag_id"], name: "index_ownerships_ownership_tags_unique", unique: true
  end

  create_table "photos", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["universe_id"], name: "index_photos_on_universe_id"
  end

  create_table "relation_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "inverse"
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.boolean "symmetric", default: true, null: false
    t.boolean "taggable", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_relation_tags_on_parent_id"
    t.index ["photo_id"], name: "index_relation_tags_on_photo_id"
    t.index ["universe_id"], name: "index_relation_tags_on_universe_id"
  end

  create_table "relations", force: :cascade do |t|
    t.integer "character1_id", null: false
    t.integer "character2_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.datetime "from_date"
    t.string "name"
    t.integer "photo_id"
    t.string "slug", null: false
    t.datetime "to_date"
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character1_id"], name: "index_relations_on_character1_id"
    t.index ["character2_id"], name: "index_relations_on_character2_id"
    t.index ["photo_id"], name: "index_relations_on_photo_id"
    t.index ["universe_id"], name: "index_relations_on_universe_id"
  end

  create_table "relations_relation_tags", id: false, force: :cascade do |t|
    t.integer "relation_id", null: false
    t.integer "relation_tag_id", null: false
    t.index ["relation_id", "relation_tag_id"], name: "index_relations_relation_tags_unique", unique: true
  end

  create_table "scene_characters", force: :cascade do |t|
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "role"
    t.integer "scene_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_scene_characters_on_character_id"
    t.index ["scene_id", "character_id"], name: "index_scene_characters_on_scene_id_and_character_id", unique: true, where: "deleted_at IS NULL"
    t.index ["scene_id"], name: "index_scene_characters_on_scene_id"
  end

  create_table "scene_element_speakers", id: false, force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "scene_element_id", null: false
    t.index ["character_id"], name: "index_scene_element_speakers_on_character_id"
    t.index ["scene_element_id", "character_id"], name: "index_scene_element_speakers_on_element_and_character", unique: true
    t.index ["scene_element_id"], name: "index_scene_element_speakers_on_scene_element_id"
  end

  create_table "scene_elements", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "kind", default: "narration", null: false
    t.string "name"
    t.integer "position", default: 0, null: false
    t.integer "scene_id", null: false
    t.datetime "updated_at", null: false
    t.index ["scene_id", "position"], name: "index_scene_elements_on_scene_id_and_position"
    t.index ["scene_id"], name: "index_scene_elements_on_scene_id"
    t.check_constraint "kind IN ('narration', 'dialogue')", name: "scene_elements_kind_is_known"
  end

  create_table "scene_items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "item_id", null: false
    t.string "role"
    t.integer "scene_id", null: false
    t.datetime "updated_at", null: false
    t.index ["item_id"], name: "index_scene_items_on_item_id"
    t.index ["scene_id", "item_id"], name: "index_scene_items_on_scene_id_and_item_id", unique: true, where: "deleted_at IS NULL"
    t.index ["scene_id"], name: "index_scene_items_on_scene_id"
  end

  create_table "scene_locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "location_id", null: false
    t.string "role"
    t.integer "scene_id", null: false
    t.datetime "updated_at", null: false
    t.index ["location_id"], name: "index_scene_locations_on_location_id"
    t.index ["scene_id", "location_id"], name: "index_scene_locations_on_scene_id_and_location_id", unique: true, where: "deleted_at IS NULL"
    t.index ["scene_id"], name: "index_scene_locations_on_scene_id"
  end

  create_table "scene_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "story_id", null: false
    t.boolean "taggable", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_scene_tags_on_parent_id"
    t.index ["photo_id"], name: "index_scene_tags_on_photo_id"
    t.index ["story_id"], name: "index_scene_tags_on_story_id"
  end

  create_table "scenes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "datetime"
    t.datetime "deleted_at"
    t.text "description"
    t.integer "event_id"
    t.string "name"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.integer "section_id"
    t.string "slug", null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["event_id"], name: "index_scenes_on_event_id"
    t.index ["photo_id"], name: "index_scenes_on_photo_id"
    t.index ["section_id"], name: "index_scenes_on_section_id"
    t.index ["story_id", "position"], name: "index_scenes_on_story_id_and_position"
    t.index ["story_id", "section_id"], name: "index_scenes_on_story_id_and_section_id"
    t.index ["story_id"], name: "index_scenes_on_story_id"
  end

  create_table "scenes_scene_tags", id: false, force: :cascade do |t|
    t.integer "scene_id", null: false
    t.integer "scene_tag_id", null: false
    t.index ["scene_id", "scene_tag_id"], name: "index_scenes_scene_tags_on_scene_id_and_scene_tag_id", unique: true
    t.index ["scene_id"], name: "index_scenes_scene_tags_on_scene_id"
    t.index ["scene_tag_id"], name: "index_scenes_scene_tags_on_scene_tag_id"
  end

  create_table "section_tags", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "story_id", null: false
    t.boolean "taggable", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_section_tags_on_parent_id"
    t.index ["photo_id"], name: "index_section_tags_on_photo_id"
    t.index ["story_id"], name: "index_section_tags_on_story_id"
  end

  create_table "sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "photo_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_sections_on_parent_id"
    t.index ["photo_id"], name: "index_sections_on_photo_id"
    t.index ["story_id"], name: "index_sections_on_story_id"
  end

  create_table "sections_section_tags", id: false, force: :cascade do |t|
    t.integer "section_id", null: false
    t.integer "section_tag_id", null: false
    t.index ["section_id", "section_tag_id"], name: "index_sections_section_tags_unique", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at"
    t.string "ip_address"
    t.datetime "last_used_at"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["expires_at"], name: "index_sessions_on_expires_at"
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.text "description"
    t.string "name"
    t.integer "photo_id"
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["photo_id"], name: "index_stories_on_photo_id"
    t.index ["universe_id", "slug"], name: "index_stories_on_universe_id_and_slug", unique: true, where: "deleted_at IS NULL"
    t.index ["universe_id"], name: "index_stories_on_universe_id"
  end

  create_table "universe_memberships", force: :cascade do |t|
    t.integer "access_level", default: 1, null: false
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id", null: false
    t.index ["universe_id", "user_id"], name: "index_universe_memberships_on_universe_id_and_user_id", unique: true, where: "deleted_at IS NULL"
    t.index ["universe_id"], name: "index_universe_memberships_on_universe_id"
    t.index ["user_id"], name: "index_universe_memberships_on_user_id"
  end

  create_table "universes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "deleted_at"
    t.string "name"
    t.integer "owner_id", null: false
    t.integer "photo_id"
    t.boolean "private", default: false, null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_universes_on_owner_id"
    t.index ["photo_id"], name: "index_universes_on_photo_id"
    t.index ["slug"], name: "index_universes_on_slug", unique: true, where: "deleted_at IS NULL"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "name", null: false
    t.string "password_digest", null: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.index ["slug"], name: "index_users_on_slug", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "character_tags", "character_tags", column: "parent_id"
  add_foreign_key "character_tags", "photos", on_delete: :nullify
  add_foreign_key "character_tags", "universes"
  add_foreign_key "characters", "characters", column: "parent_id"
  add_foreign_key "characters", "photos", on_delete: :nullify
  add_foreign_key "characters", "universes"
  add_foreign_key "characters_character_tags", "character_tags"
  add_foreign_key "characters_character_tags", "characters"
  add_foreign_key "event_tags", "event_tags", column: "parent_id"
  add_foreign_key "event_tags", "photos", on_delete: :nullify
  add_foreign_key "event_tags", "universes"
  add_foreign_key "events", "events", column: "after_event_id"
  add_foreign_key "events", "events", column: "before_event_id"
  add_foreign_key "events", "events", column: "parent_id"
  add_foreign_key "events", "events", column: "simultaneous_event_id"
  add_foreign_key "events", "photos", on_delete: :nullify
  add_foreign_key "events", "universes"
  add_foreign_key "events_event_tags", "event_tags"
  add_foreign_key "events_event_tags", "events"
  add_foreign_key "item_tags", "item_tags", column: "parent_id"
  add_foreign_key "item_tags", "photos", on_delete: :nullify
  add_foreign_key "item_tags", "universes"
  add_foreign_key "items", "items", column: "parent_id"
  add_foreign_key "items", "photos", on_delete: :nullify
  add_foreign_key "items", "universes"
  add_foreign_key "items_item_tags", "item_tags"
  add_foreign_key "items_item_tags", "items"
  add_foreign_key "location_tags", "location_tags", column: "parent_id"
  add_foreign_key "location_tags", "photos", on_delete: :nullify
  add_foreign_key "location_tags", "universes"
  add_foreign_key "locations", "locations", column: "parent_id"
  add_foreign_key "locations", "photos", on_delete: :nullify
  add_foreign_key "locations", "universes"
  add_foreign_key "locations_location_tags", "location_tags"
  add_foreign_key "locations_location_tags", "locations"
  add_foreign_key "ownership_tags", "ownership_tags", column: "parent_id"
  add_foreign_key "ownership_tags", "photos", on_delete: :nullify
  add_foreign_key "ownership_tags", "universes"
  add_foreign_key "ownerships", "characters"
  add_foreign_key "ownerships", "items"
  add_foreign_key "ownerships", "photos", on_delete: :nullify
  add_foreign_key "ownerships", "universes"
  add_foreign_key "ownerships_ownership_tags", "ownership_tags"
  add_foreign_key "ownerships_ownership_tags", "ownerships"
  add_foreign_key "photos", "universes"
  add_foreign_key "relation_tags", "photos", on_delete: :nullify
  add_foreign_key "relation_tags", "relation_tags", column: "parent_id"
  add_foreign_key "relation_tags", "universes"
  add_foreign_key "relations", "characters", column: "character1_id"
  add_foreign_key "relations", "characters", column: "character2_id"
  add_foreign_key "relations", "photos", on_delete: :nullify
  add_foreign_key "relations", "universes"
  add_foreign_key "relations_relation_tags", "relation_tags"
  add_foreign_key "relations_relation_tags", "relations"
  add_foreign_key "scene_characters", "characters"
  add_foreign_key "scene_characters", "scenes"
  add_foreign_key "scene_element_speakers", "characters"
  add_foreign_key "scene_element_speakers", "scene_elements"
  add_foreign_key "scene_elements", "scenes"
  add_foreign_key "scene_items", "items"
  add_foreign_key "scene_items", "scenes"
  add_foreign_key "scene_locations", "locations"
  add_foreign_key "scene_locations", "scenes"
  add_foreign_key "scene_tags", "photos", on_delete: :nullify
  add_foreign_key "scene_tags", "scene_tags", column: "parent_id"
  add_foreign_key "scene_tags", "stories"
  add_foreign_key "scenes", "events"
  add_foreign_key "scenes", "photos", on_delete: :nullify
  add_foreign_key "scenes", "sections"
  add_foreign_key "scenes", "stories"
  add_foreign_key "scenes_scene_tags", "scene_tags"
  add_foreign_key "scenes_scene_tags", "scenes"
  add_foreign_key "section_tags", "photos", on_delete: :nullify
  add_foreign_key "section_tags", "section_tags", column: "parent_id"
  add_foreign_key "section_tags", "stories"
  add_foreign_key "sections", "photos", on_delete: :nullify
  add_foreign_key "sections", "sections", column: "parent_id"
  add_foreign_key "sections", "stories"
  add_foreign_key "sections_section_tags", "section_tags"
  add_foreign_key "sections_section_tags", "sections"
  add_foreign_key "sessions", "users"
  add_foreign_key "stories", "photos", on_delete: :nullify
  add_foreign_key "stories", "universes"
  add_foreign_key "universe_memberships", "universes"
  add_foreign_key "universe_memberships", "users"
  add_foreign_key "universes", "photos", on_delete: :nullify
  add_foreign_key "universes", "users", column: "owner_id"
end
