class AddExternalSyncFieldsToInvoices < ActiveRecord::Migration[8.1]
  def up
    change_table :invoices, bulk: true do |t|
      t.string :source_origin, null: false, default: "local"
      t.string :external_visibility_state, null: false, default: "mapped"
      t.datetime :imported_from_facturador_at
      t.datetime :last_external_sync_at
      t.jsonb :external_raw_snapshot, null: false, default: {}
      t.string :external_dedup_fingerprint
    end

    add_index :invoices, :source_origin
    add_index :invoices, :external_visibility_state
    add_index :invoices, :last_external_sync_at
    add_index :invoices, [ :external_visibility_state, :created_at ],
      name: "index_invoices_on_visibility_state_and_created_at"
    add_index :invoices, :external_dedup_fingerprint,
      unique: true,
      where: "external_dedup_fingerprint IS NOT NULL AND source_origin = 'facturador_external'",
      name: "index_invoices_on_external_fingerprint_unique"

    add_check_constraint :invoices,
      "source_origin IN ('local', 'facturador_external')",
      name: "check_invoices_source_origin"
    add_check_constraint :invoices,
      "external_visibility_state IN ('mapped', 'pending_assignment')",
      name: "check_invoices_external_visibility_state"

    execute <<~SQL.squish
      UPDATE invoices
      SET source_origin = 'local',
          external_visibility_state = 'mapped'
      WHERE source_origin IS NULL OR external_visibility_state IS NULL
    SQL
  end

  def down
    remove_check_constraint :invoices, name: "check_invoices_external_visibility_state"
    remove_check_constraint :invoices, name: "check_invoices_source_origin"

    remove_index :invoices, name: "index_invoices_on_external_fingerprint_unique"
    remove_index :invoices, name: "index_invoices_on_visibility_state_and_created_at"
    remove_index :invoices, :last_external_sync_at
    remove_index :invoices, :external_visibility_state
    remove_index :invoices, :source_origin

    change_table :invoices, bulk: true do |t|
      t.remove :external_dedup_fingerprint
      t.remove :external_raw_snapshot
      t.remove :last_external_sync_at
      t.remove :imported_from_facturador_at
      t.remove :external_visibility_state
      t.remove :source_origin
    end
  end
end
