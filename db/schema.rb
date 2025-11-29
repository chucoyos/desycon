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

ActiveRecord::Schema[8.1].define(version: 2025_11_29_055105) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "addresses", force: :cascade do |t|
    t.bigint "addressable_id", null: false
    t.string "addressable_type", null: false
    t.string "calle"
    t.string "codigo_postal", null: false
    t.string "colonia"
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.string "estado", null: false
    t.string "localidad"
    t.string "municipio"
    t.string "numero_exterior"
    t.string "numero_interior"
    t.string "pais", null: false
    t.string "tipo"
    t.datetime "updated_at", null: false
    t.index ["addressable_type", "addressable_id", "tipo"], name: "index_addresses_on_addressable_and_tipo"
    t.index ["codigo_postal"], name: "index_addresses_on_codigo_postal"
  end

  create_table "fiscal_profiles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "forma_pago"
    t.string "metodo_pago"
    t.bigint "profileable_id", null: false
    t.string "profileable_type", null: false
    t.string "razon_social", null: false
    t.string "regimen", null: false
    t.string "rfc", null: false
    t.datetime "updated_at", null: false
    t.string "uso_cfdi"
    t.index ["profileable_type", "profileable_id"], name: "index_fiscal_profiles_on_profileable", unique: true
    t.index ["rfc"], name: "index_fiscal_profiles_on_rfc"
  end

  create_table "ports", force: :cascade do |t|
    t.string "code", null: false
    t.string "country_code", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["code"], name: "index_ports_on_code", unique: true
    t.index ["country_code", "name"], name: "index_ports_on_country_code_and_name"
    t.index ["country_code"], name: "index_ports_on_country_code"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "shipping_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "vessels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "shipping_line_id", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_vessels_on_name", unique: true
    t.index ["shipping_line_id", "name"], name: "index_vessels_on_shipping_line_and_name"
    t.index ["shipping_line_id"], name: "index_vessels_on_shipping_line_id"
  end

  add_foreign_key "users", "roles"
  add_foreign_key "vessels", "shipping_lines"
end
