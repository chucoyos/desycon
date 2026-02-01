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

ActiveRecord::Schema[8.1].define(version: 2026_02_01_120000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "bl_house_line_services", force: :cascade do |t|
    t.bigint "billed_to_entity_id"
    t.bigint "bl_house_line_id", null: false
    t.datetime "created_at", null: false
    t.string "factura"
    t.date "fecha_programada"
    t.text "observaciones"
    t.bigint "service_catalog_id", null: false
    t.datetime "updated_at", null: false
    t.index ["billed_to_entity_id"], name: "index_bl_house_line_services_on_billed_to_entity_id"
    t.index ["bl_house_line_id"], name: "index_bl_house_line_services_on_bl_house_line_id"
    t.index ["factura"], name: "index_bl_house_line_services_on_factura"
    t.index ["fecha_programada"], name: "index_bl_house_line_services_on_fecha_programada"
    t.index ["service_catalog_id"], name: "index_bl_house_line_services_on_service_catalog_id"
  end

  create_table "bl_house_line_status_histories", force: :cascade do |t|
    t.bigint "bl_house_line_id"
    t.datetime "changed_at"
    t.bigint "changed_by_id"
    t.string "changed_by_type"
    t.datetime "created_at", null: false
    t.text "observations"
    t.string "previous_status"
    t.string "status"
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["bl_house_line_id"], name: "index_bl_house_line_status_histories_on_bl_house_line_id"
    t.index ["changed_by_type", "changed_by_id"], name: "index_bl_house_line_status_histories_on_changed_by"
    t.index ["user_id"], name: "index_bl_house_line_status_histories_on_user_id"
  end

  create_table "bl_house_lines", force: :cascade do |t|
    t.boolean "bl_endosado_documento_validated", default: false, null: false
    t.string "blhouse"
    t.integer "cantidad"
    t.string "clase_imo"
    t.bigint "client_id"
    t.bigint "container_id"
    t.text "contiene"
    t.datetime "created_at", null: false
    t.bigint "customs_agent_id"
    t.bigint "customs_agent_patent_id"
    t.boolean "encomienda_documento_validated", default: false, null: false
    t.date "fecha_despacho"
    t.boolean "hidden_from_customs_agent", default: false, null: false
    t.boolean "liberacion_documento_validated", default: false, null: false
    t.text "marcas"
    t.bigint "packaging_id"
    t.boolean "pago_documento_validated", default: false, null: false
    t.integer "partida"
    t.decimal "peso"
    t.string "status"
    t.string "tipo_imo"
    t.datetime "updated_at", null: false
    t.decimal "volumen"
    t.index ["client_id"], name: "index_bl_house_lines_on_client_id"
    t.index ["container_id"], name: "index_bl_house_lines_on_container_id"
    t.index ["customs_agent_id"], name: "index_bl_house_lines_on_customs_agent_id"
    t.index ["customs_agent_patent_id"], name: "index_bl_house_lines_on_customs_agent_patent_id"
    t.index ["hidden_from_customs_agent"], name: "index_bl_house_lines_on_hidden_from_customs_agent"
    t.index ["packaging_id"], name: "index_bl_house_lines_on_packaging_id"
  end

  create_table "clients", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_clients_on_entity_id"
  end

  create_table "consolidators", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_consolidators_on_entity_id"
  end

  create_table "consolidators_old", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_consolidators_old_on_name", unique: true
  end

  create_table "container_services", force: :cascade do |t|
    t.bigint "billed_to_entity_id"
    t.bigint "container_id", null: false
    t.datetime "created_at", null: false
    t.string "factura"
    t.date "fecha_programada"
    t.text "observaciones"
    t.bigint "service_catalog_id", null: false
    t.datetime "updated_at", null: false
    t.index ["billed_to_entity_id"], name: "index_container_services_on_billed_to_entity_id"
    t.index ["container_id"], name: "index_container_services_on_container_id"
    t.index ["factura"], name: "index_container_services_on_factura"
    t.index ["fecha_programada"], name: "index_container_services_on_fecha_programada"
    t.index ["service_catalog_id"], name: "index_container_services_on_service_catalog_id"
  end

  create_table "container_status_histories", force: :cascade do |t|
    t.bigint "container_id", null: false
    t.datetime "created_at", null: false
    t.datetime "fecha_actualizacion", null: false
    t.text "observaciones"
    t.string "status", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id"
    t.index ["container_id", "fecha_actualizacion"], name: "index_status_histories_on_container_and_date"
    t.index ["container_id"], name: "index_container_status_histories_on_container_id"
    t.index ["fecha_actualizacion"], name: "index_container_status_histories_on_fecha_actualizacion"
    t.index ["status"], name: "index_container_status_histories_on_status"
    t.index ["user_id"], name: "index_container_status_histories_on_user_id"
  end

  create_table "containers", force: :cascade do |t|
    t.string "almacen"
    t.string "archivo_nr"
    t.string "bl_master"
    t.bigint "consolidator_entity_id"
    t.bigint "consolidator_id"
    t.datetime "created_at", null: false
    t.string "ejecutivo"
    t.date "fecha_descarga"
    t.date "fecha_desconsolidacion"
    t.date "fecha_revalidacion_bl_master"
    t.datetime "fecha_transferencia"
    t.string "number", null: false
    t.bigint "origin_port_id"
    t.string "recinto"
    t.string "sello"
    t.bigint "shipping_line_id", null: false
    t.string "status", default: "activo", null: false
    t.string "tipo_maniobra", null: false
    t.string "type_size"
    t.datetime "updated_at", null: false
    t.bigint "vessel_id"
    t.bigint "voyage_id"
    t.index ["consolidator_id"], name: "index_containers_on_consolidator_id"
    t.index ["number", "bl_master"], name: "index_containers_on_number_and_bl_master", unique: true
    t.index ["origin_port_id"], name: "index_containers_on_origin_port_id"
    t.index ["shipping_line_id"], name: "index_containers_on_shipping_line_id"
    t.index ["status"], name: "index_containers_on_status"
    t.index ["tipo_maniobra"], name: "index_containers_on_tipo_maniobra"
    t.index ["type_size"], name: "index_containers_on_type_size"
    t.index ["vessel_id"], name: "index_containers_on_vessel_id"
    t.index ["voyage_id"], name: "index_containers_on_voyage_id"
  end

  create_table "customs_agent_patents", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.string "patent_number", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id", "patent_number"], name: "index_patents_on_entity_and_number", unique: true
    t.index ["entity_id"], name: "index_customs_agent_patents_on_entity_id"
  end

  create_table "entities", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "customs_agent_id"
    t.boolean "is_client", default: false
    t.boolean "is_consolidator", default: false
    t.boolean "is_customs_agent", default: false
    t.boolean "is_forwarder", default: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["customs_agent_id"], name: "index_entities_on_customs_agent_id"
    t.index ["name"], name: "index_entities_on_name"
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

  create_table "forwarders", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "entity_id", null: false
    t.datetime "updated_at", null: false
    t.index ["entity_id"], name: "index_forwarders_on_entity_id"
  end

  create_table "notifications", force: :cascade do |t|
    t.string "action"
    t.bigint "actor_id", null: false
    t.datetime "created_at", null: false
    t.bigint "notifiable_id", null: false
    t.string "notifiable_type", null: false
    t.datetime "read_at"
    t.bigint "recipient_id", null: false
    t.datetime "updated_at", null: false
    t.index ["actor_id"], name: "index_notifications_on_actor_id"
    t.index ["notifiable_type", "notifiable_id"], name: "index_notifications_on_notifiable"
    t.index ["recipient_id"], name: "index_notifications_on_recipient_id"
  end

  create_table "packagings", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "nombre"
    t.datetime "updated_at", null: false
  end

  create_table "permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_permissions_on_key", unique: true
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

  create_table "role_permissions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "permission_id", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["permission_id"], name: "index_role_permissions_on_permission_id"
    t.index ["role_id", "permission_id"], name: "index_role_permissions_on_role_id_and_permission_id", unique: true
    t.index ["role_id"], name: "index_role_permissions_on_role_id"
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_roles_on_name", unique: true
  end

  create_table "service_catalogs", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "applies_to", null: false
    t.string "code"
    t.datetime "created_at", null: false
    t.string "currency", default: "MXN", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["applies_to", "name"], name: "index_service_catalogs_on_applies_to_and_name", unique: true
    t.index ["code"], name: "index_service_catalogs_on_code", unique: true
  end

  create_table "shipping_lines", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "iso_code"
    t.string "name"
    t.datetime "updated_at", null: false
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.boolean "disabled", default: false, null: false
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.bigint "entity_id"
    t.datetime "remember_created_at"
    t.datetime "reset_password_sent_at"
    t.string "reset_password_token"
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.index ["disabled"], name: "index_users_on_disabled"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["entity_id"], name: "index_users_on_entity_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["role_id"], name: "index_users_on_role_id"
  end

  create_table "vessels", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["name"], name: "index_vessels_on_name", unique: true
  end

  create_table "voyages", force: :cascade do |t|
    t.datetime "ata"
    t.datetime "created_at", null: false
    t.bigint "destination_port_id"
    t.datetime "eta"
    t.datetime "fin_operacion"
    t.datetime "inicio_operacion"
    t.datetime "updated_at", null: false
    t.bigint "vessel_id", null: false
    t.string "viaje", null: false
    t.string "voyage_type", null: false
    t.index ["destination_port_id"], name: "index_voyages_on_destination_port_id"
    t.index ["vessel_id", "viaje"], name: "index_voyages_on_vessel_id_and_viaje", unique: true
    t.index ["vessel_id"], name: "index_voyages_on_vessel_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "bl_house_line_services", "bl_house_lines"
  add_foreign_key "bl_house_line_services", "entities", column: "billed_to_entity_id"
  add_foreign_key "bl_house_line_services", "service_catalogs"
  add_foreign_key "bl_house_line_status_histories", "bl_house_lines"
  add_foreign_key "bl_house_lines", "containers"
  add_foreign_key "bl_house_lines", "customs_agent_patents"
  add_foreign_key "bl_house_lines", "entities", column: "client_id"
  add_foreign_key "bl_house_lines", "entities", column: "customs_agent_id"
  add_foreign_key "bl_house_lines", "packagings"
  add_foreign_key "clients", "entities"
  add_foreign_key "consolidators", "entities"
  add_foreign_key "container_services", "containers"
  add_foreign_key "container_services", "entities", column: "billed_to_entity_id"
  add_foreign_key "container_services", "service_catalogs"
  add_foreign_key "container_status_histories", "containers"
  add_foreign_key "container_status_histories", "users"
  add_foreign_key "containers", "entities", column: "consolidator_entity_id", name: "containers_consolidator_entity_id_fkey"
  add_foreign_key "containers", "ports", column: "origin_port_id"
  add_foreign_key "containers", "shipping_lines"
  add_foreign_key "containers", "vessels"
  add_foreign_key "containers", "voyages"
  add_foreign_key "customs_agent_patents", "entities"
  add_foreign_key "entities", "entities", column: "customs_agent_id"
  add_foreign_key "forwarders", "entities"
  add_foreign_key "notifications", "users", column: "actor_id"
  add_foreign_key "notifications", "users", column: "recipient_id"
  add_foreign_key "role_permissions", "permissions"
  add_foreign_key "role_permissions", "roles"
  add_foreign_key "users", "entities"
  add_foreign_key "users", "roles"
  add_foreign_key "voyages", "ports", column: "destination_port_id"
  add_foreign_key "voyages", "vessels"
end
