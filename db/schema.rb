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

ActiveRecord::Schema[8.1].define(version: 2026_08_14_034948) do
  create_table "care_events", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "kind", null: false
    t.text "note"
    t.date "occurred_on", null: false
    t.integer "pot_id", null: false
    t.string "product"
    t.datetime "updated_at", null: false
    t.index ["pot_id", "kind", "occurred_on"], name: "index_care_events_on_pot_id_and_kind_and_occurred_on"
    t.index ["pot_id"], name: "index_care_events_on_pot_id"
  end

  create_table "locations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "exposure"
    t.string "grow_light_entity_id"
    t.string "name", null: false
    t.string "natural_light", default: "medium", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_locations_on_name", unique: true
    t.index ["position"], name: "index_locations_on_position"
  end

  create_table "moisture_readings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "pot_id", null: false
    t.datetime "read_at", null: false
    t.string "source", default: "manual", null: false
    t.datetime "updated_at", null: false
    t.decimal "value", precision: 5, scale: 2, null: false
    t.index ["pot_id", "read_at"], name: "index_moisture_readings_on_pot_id_and_read_at"
    t.index ["pot_id"], name: "index_moisture_readings_on_pot_id"
  end

  create_table "plants", force: :cascade do |t|
    t.date "acquired_on"
    t.datetime "created_at", null: false
    t.string "light_requirement", default: "medium", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "pot_id", null: false
    t.string "reference_url"
    t.string "species"
    t.datetime "updated_at", null: false
    t.index ["pot_id"], name: "index_plants_on_pot_id"
  end

  create_table "pots", force: :cascade do |t|
    t.integer "check_interval_days", default: 7, null: false
    t.datetime "created_at", null: false
    t.integer "dry_below", default: 20, null: false
    t.integer "fertilize_interval_days"
    t.integer "location_id", null: false
    t.string "medium", default: "soil", null: false
    t.string "name", null: false
    t.text "notes"
    t.integer "position", default: 0, null: false
    t.date "potted_on"
    t.datetime "updated_at", null: false
    t.json "voice_aliases", default: [], null: false
    t.integer "water_interval_days"
    t.integer "wet_above", default: 100, null: false
    t.index ["location_id", "position"], name: "index_pots_on_location_id_and_position"
    t.index ["location_id"], name: "index_pots_on_location_id"
  end

  add_foreign_key "care_events", "pots"
  add_foreign_key "moisture_readings", "pots"
  add_foreign_key "plants", "pots"
  add_foreign_key "pots", "locations"
end
