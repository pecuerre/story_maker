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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_000000) do
  create_table "character_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_character_types_on_parent_id"
    t.index ["story_id"], name: "index_character_types_on_story_id"
  end

  create_table "characters", force: :cascade do |t|
    t.integer "character_type_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character_type_id"], name: "index_characters_on_character_type_id"
    t.index ["parent_id"], name: "index_characters_on_parent_id"
    t.index ["story_id"], name: "index_characters_on_story_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "after_event_id"
    t.integer "before_event_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "end_datetime"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "simultaneous_event_id"
    t.datetime "start_datetime"
    t.integer "story_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.index ["after_event_id"], name: "index_events_on_after_event_id"
    t.index ["before_event_id"], name: "index_events_on_before_event_id"
    t.index ["parent_id"], name: "index_events_on_parent_id"
    t.index ["simultaneous_event_id"], name: "index_events_on_simultaneous_event_id"
    t.index ["story_id"], name: "index_events_on_story_id"
  end

  create_table "item_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_item_types_on_parent_id"
    t.index ["story_id"], name: "index_item_types_on_story_id"
  end

  create_table "items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "item_type_id", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["item_type_id"], name: "index_items_on_item_type_id"
    t.index ["parent_id"], name: "index_items_on_parent_id"
    t.index ["story_id"], name: "index_items_on_story_id"
  end

  create_table "location_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_location_types_on_parent_id"
    t.index ["story_id"], name: "index_location_types_on_story_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.integer "location_type_id", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["location_type_id"], name: "index_locations_on_location_type_id"
    t.index ["parent_id"], name: "index_locations_on_parent_id"
    t.index ["story_id"], name: "index_locations_on_story_id"
  end

  create_table "ownership_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_ownership_types_on_parent_id"
    t.index ["story_id"], name: "index_ownership_types_on_story_id"
  end

  create_table "ownerships", force: :cascade do |t|
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "from_date"
    t.integer "item_id", null: false
    t.integer "ownership_type_id", null: false
    t.integer "story_id", null: false
    t.datetime "to_date"
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_ownerships_on_character_id"
    t.index ["item_id"], name: "index_ownerships_on_item_id"
    t.index ["ownership_type_id"], name: "index_ownerships_on_ownership_type_id"
    t.index ["story_id"], name: "index_ownerships_on_story_id"
  end

  create_table "relation_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "inverse"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.boolean "symmetric", default: true, null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_relation_types_on_parent_id"
    t.index ["story_id"], name: "index_relation_types_on_story_id"
  end

  create_table "relations", force: :cascade do |t|
    t.integer "character1_id", null: false
    t.integer "character2_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "from_date"
    t.integer "relation_type_id", null: false
    t.integer "story_id", null: false
    t.datetime "to_date"
    t.datetime "updated_at", null: false
    t.index ["character1_id"], name: "index_relations_on_character1_id"
    t.index ["character2_id"], name: "index_relations_on_character2_id"
    t.index ["relation_type_id"], name: "index_relations_on_relation_type_id"
    t.index ["story_id"], name: "index_relations_on_story_id"
  end

  create_table "section_types", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_section_types_on_parent_id"
    t.index ["story_id"], name: "index_section_types_on_story_id"
  end

  create_table "sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.integer "section_type_id", null: false
    t.integer "story_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_sections_on_parent_id"
    t.index ["section_type_id"], name: "index_sections_on_section_type_id"
    t.index ["story_id"], name: "index_sections_on_story_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "stories", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "owner_id", null: false
    t.boolean "private", default: false
    t.string "slug"
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_stories_on_owner_id"
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "character_types", "character_types", column: "parent_id"
  add_foreign_key "character_types", "stories"
  add_foreign_key "characters", "character_types"
  add_foreign_key "characters", "characters", column: "parent_id"
  add_foreign_key "characters", "stories"
  add_foreign_key "events", "events", column: "after_event_id"
  add_foreign_key "events", "events", column: "before_event_id"
  add_foreign_key "events", "events", column: "parent_id"
  add_foreign_key "events", "events", column: "simultaneous_event_id"
  add_foreign_key "events", "stories"
  add_foreign_key "item_types", "item_types", column: "parent_id"
  add_foreign_key "item_types", "stories"
  add_foreign_key "items", "item_types"
  add_foreign_key "items", "items", column: "parent_id"
  add_foreign_key "items", "stories"
  add_foreign_key "location_types", "location_types", column: "parent_id"
  add_foreign_key "location_types", "stories"
  add_foreign_key "locations", "location_types"
  add_foreign_key "locations", "locations", column: "parent_id"
  add_foreign_key "locations", "stories"
  add_foreign_key "ownership_types", "ownership_types", column: "parent_id"
  add_foreign_key "ownership_types", "stories"
  add_foreign_key "ownerships", "characters"
  add_foreign_key "ownerships", "items"
  add_foreign_key "ownerships", "ownership_types"
  add_foreign_key "ownerships", "stories"
  add_foreign_key "relation_types", "relation_types", column: "parent_id"
  add_foreign_key "relation_types", "stories"
  add_foreign_key "relations", "characters", column: "character1_id"
  add_foreign_key "relations", "characters", column: "character2_id"
  add_foreign_key "relations", "relation_types"
  add_foreign_key "relations", "stories"
  add_foreign_key "section_types", "section_types", column: "parent_id"
  add_foreign_key "section_types", "stories"
  add_foreign_key "sections", "section_types"
  add_foreign_key "sections", "sections", column: "parent_id"
  add_foreign_key "sections", "stories"
  add_foreign_key "sessions", "users"
  add_foreign_key "stories", "users", column: "owner_id"
end
