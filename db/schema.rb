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

ActiveRecord::Schema[8.1].define(version: 2026_09_10_040000) do
  create_table "character_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_character_types_on_parent_id"
    t.index ["universe_id"], name: "index_character_types_on_universe_id"
  end

  create_table "characters", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_characters_on_parent_id"
    t.index ["universe_id"], name: "index_characters_on_universe_id"
  end

  create_table "characters_character_types", id: false, force: :cascade do |t|
    t.integer "character_id", null: false
    t.integer "character_type_id", null: false
  end

  create_table "event_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_event_types_on_parent_id"
    t.index ["universe_id"], name: "index_event_types_on_universe_id"
  end

  create_table "events", force: :cascade do |t|
    t.integer "after_event_id"
    t.integer "before_event_id"
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "end_datetime"
    t.string "name"
    t.integer "parent_id"
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
    t.index ["simultaneous_event_id"], name: "index_events_on_simultaneous_event_id"
    t.index ["universe_id"], name: "index_events_on_universe_id"
  end

  create_table "events_event_types", id: false, force: :cascade do |t|
    t.integer "event_id", null: false
    t.integer "event_type_id", null: false
  end

  create_table "item_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_item_types_on_parent_id"
    t.index ["universe_id"], name: "index_item_types_on_universe_id"
  end

  create_table "items", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_items_on_parent_id"
    t.index ["universe_id"], name: "index_items_on_universe_id"
  end

  create_table "items_item_types", id: false, force: :cascade do |t|
    t.integer "item_id", null: false
    t.integer "item_type_id", null: false
  end

  create_table "location_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_location_types_on_parent_id"
    t.index ["universe_id"], name: "index_location_types_on_universe_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_locations_on_parent_id"
    t.index ["universe_id"], name: "index_locations_on_universe_id"
  end

  create_table "locations_location_types", id: false, force: :cascade do |t|
    t.integer "location_id", null: false
    t.integer "location_type_id", null: false
  end

  create_table "ownership_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_ownership_types_on_parent_id"
    t.index ["universe_id"], name: "index_ownership_types_on_universe_id"
  end

  create_table "ownerships", force: :cascade do |t|
    t.integer "character_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "from_date"
    t.integer "item_id", null: false
    t.string "name"
    t.string "slug", null: false
    t.datetime "to_date"
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character_id"], name: "index_ownerships_on_character_id"
    t.index ["item_id"], name: "index_ownerships_on_item_id"
    t.index ["universe_id"], name: "index_ownerships_on_universe_id"
  end

  create_table "ownerships_ownership_types", id: false, force: :cascade do |t|
    t.integer "ownership_id", null: false
    t.integer "ownership_type_id", null: false
  end

  create_table "relation_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "inverse"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.boolean "symmetric", default: true, null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_relation_types_on_parent_id"
    t.index ["universe_id"], name: "index_relation_types_on_universe_id"
  end

  create_table "relations", force: :cascade do |t|
    t.integer "character1_id", null: false
    t.integer "character2_id", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.datetime "from_date"
    t.string "name"
    t.string "slug", null: false
    t.datetime "to_date"
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["character1_id"], name: "index_relations_on_character1_id"
    t.index ["character2_id"], name: "index_relations_on_character2_id"
    t.index ["universe_id"], name: "index_relations_on_universe_id"
  end

  create_table "relations_relation_types", id: false, force: :cascade do |t|
    t.integer "relation_id", null: false
    t.integer "relation_type_id", null: false
  end

  create_table "section_types", force: :cascade do |t|
    t.string "bgcolor", default: "#d3d3d3", null: false
    t.datetime "created_at", null: false
    t.text "description"
    t.string "fgcolor", default: "#000000", null: false
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_section_types_on_parent_id"
    t.index ["universe_id"], name: "index_section_types_on_universe_id"
  end

  create_table "sections", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "name"
    t.integer "parent_id"
    t.integer "position", default: 0, null: false
    t.string "slug", null: false
    t.integer "universe_id", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_sections_on_parent_id"
    t.index ["universe_id"], name: "index_sections_on_universe_id"
  end

  create_table "sections_section_types", id: false, force: :cascade do |t|
    t.integer "section_id", null: false
    t.integer "section_type_id", null: false
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "universes", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.integer "owner_id", null: false
    t.boolean "private", default: false
    t.string "slug", null: false
    t.datetime "updated_at", null: false
    t.index ["owner_id"], name: "index_universes_on_owner_id"
    t.index ["slug"], name: "index_universes_on_slug", unique: true
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

  add_foreign_key "character_types", "character_types", column: "parent_id"
  add_foreign_key "character_types", "universes"
  add_foreign_key "characters", "characters", column: "parent_id"
  add_foreign_key "characters", "universes"
  add_foreign_key "event_types", "event_types", column: "parent_id"
  add_foreign_key "event_types", "universes"
  add_foreign_key "events", "events", column: "after_event_id"
  add_foreign_key "events", "events", column: "before_event_id"
  add_foreign_key "events", "events", column: "parent_id"
  add_foreign_key "events", "events", column: "simultaneous_event_id"
  add_foreign_key "events", "universes"
  add_foreign_key "item_types", "item_types", column: "parent_id"
  add_foreign_key "item_types", "universes"
  add_foreign_key "items", "items", column: "parent_id"
  add_foreign_key "items", "universes"
  add_foreign_key "location_types", "location_types", column: "parent_id"
  add_foreign_key "location_types", "universes"
  add_foreign_key "locations", "locations", column: "parent_id"
  add_foreign_key "locations", "universes"
  add_foreign_key "ownership_types", "ownership_types", column: "parent_id"
  add_foreign_key "ownership_types", "universes"
  add_foreign_key "ownerships", "characters"
  add_foreign_key "ownerships", "items"
  add_foreign_key "ownerships", "universes"
  add_foreign_key "relation_types", "relation_types", column: "parent_id"
  add_foreign_key "relation_types", "universes"
  add_foreign_key "relations", "characters", column: "character1_id"
  add_foreign_key "relations", "characters", column: "character2_id"
  add_foreign_key "relations", "universes"
  add_foreign_key "section_types", "section_types", column: "parent_id"
  add_foreign_key "section_types", "universes"
  add_foreign_key "sections", "sections", column: "parent_id"
  add_foreign_key "sections", "universes"
  add_foreign_key "sessions", "users"
  add_foreign_key "universes", "users", column: "owner_id"
end
