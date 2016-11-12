# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# Note that this schema.rb definition is the authoritative source for your
# database schema. If you need to create the application database on another
# system, you should be using db:schema:load, not running all the migrations
# from scratch. The latter is a flawed and unsustainable approach (the more migrations
# you'll amass, the slower it'll run and the greater likelihood for issues).
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema.define(version: 20161030181249) do

  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "checks", force: :cascade do |t|
    t.string   "title"
    t.integer  "user_id"
    t.boolean  "is_complete", default: false
    t.datetime "created_at",                  null: false
    t.datetime "updated_at",                  null: false
    t.string   "image"
  end

  create_table "details", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "position_id"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["position_id"], name: "index_details_on_position_id", using: :btree
    t.index ["user_id"], name: "index_details_on_user_id", using: :btree
  end

  create_table "pays", force: :cascade do |t|
    t.integer  "user_id"
    t.integer  "check_id"
    t.decimal  "debt"
    t.boolean  "is_complete"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.index ["check_id"], name: "index_pays_on_check_id", using: :btree
    t.index ["user_id"], name: "index_pays_on_user_id", using: :btree
  end

  create_table "positions", force: :cascade do |t|
    t.string   "title"
    t.integer  "number_of_people", default: 1
    t.decimal  "price"
    t.integer  "custom_id"
    t.integer  "check_id"
    t.datetime "created_at",                   null: false
    t.datetime "updated_at",                   null: false
  end

  create_table "users", force: :cascade do |t|
    t.string   "telegram_id"
    t.string   "first_name"
    t.string   "last_name"
    t.datetime "created_at",  null: false
    t.datetime "updated_at",  null: false
    t.string   "aasm_state"
  end

  add_foreign_key "details", "positions"
  add_foreign_key "details", "users"
  add_foreign_key "pays", "checks"
  add_foreign_key "pays", "users"
end
