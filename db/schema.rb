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

ActiveRecord::Schema[8.0].define(version: 2025_07_28_034742) do
  create_table "location_types", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "story_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["story_id"], name: "index_location_types_on_story_id"
  end

  create_table "locations", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.integer "story_id", null: false
    t.integer "location_type_id", null: false
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["location_type_id"], name: "index_locations_on_location_type_id"
    t.index ["story_id"], name: "index_locations_on_story_id"
  end

  create_table "stories", force: :cascade do |t|
    t.string "name"
    t.string "slug"
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "taxonomies", force: :cascade do |t|
    t.string "name"
    t.text "description"
    t.string "slug"
    t.boolean "fixed", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
  end

  create_table "taxons", force: :cascade do |t|
    t.string "name"
    t.integer "taxonomy_id", null: false
    t.integer "parent_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["parent_id"], name: "index_taxons_on_parent_id"
    t.index ["taxonomy_id"], name: "index_taxons_on_taxonomy_id"
  end

  add_foreign_key "location_types", "stories"
  add_foreign_key "locations", "location_types"
  add_foreign_key "locations", "stories"
  add_foreign_key "taxons", "taxonomies"
  add_foreign_key "taxons", "taxons", column: "parent_id"
end
