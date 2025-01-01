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

ActiveRecord::Schema[7.2].define(version: 2024_10_31_182331) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "citext"
  enable_extension "pg_trgm"
  enable_extension "plpgsql"

  create_table "accounts", force: :cascade do |t|
    t.boolean "enabled", default: false, null: false
    t.citext "email", null: false
    t.citext "username", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_accounts_on_email", unique: true
    t.index ["person_id"], name: "index_accounts_on_person_id"
    t.index ["username"], name: "index_accounts_on_username", unique: true
  end

  create_table "people", force: :cascade do |t|
    t.string "last_name", null: false
    t.string "first_name", null: false
    t.date "birthdate", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["last_name", "first_name", "birthdate"], name: "index_people_on_last_name_and_first_name_and_birthdate", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.string "job_title", null: false
    t.string "department", null: false
    t.bigint "person_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["person_id", "job_title", "department"], name: "index_roles_on_person_id_and_job_title_and_department", unique: true
    t.index ["person_id"], name: "index_roles_on_person_id"
  end

  add_foreign_key "accounts", "people"
  add_foreign_key "roles", "people"
end
