class CreateInvoicesAndInvoiceEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :invoiceable, polymorphic: true, null: false
      t.references :issuer_entity, null: false, foreign_key: { to_table: :entities }
      t.references :receiver_entity, null: false, foreign_key: { to_table: :entities }

      t.string :kind, null: false, default: "ingreso"
      t.string :status, null: false, default: "draft"
      t.string :currency, null: false, default: "MXN"

      t.decimal :subtotal, precision: 12, scale: 2, null: false, default: 0
      t.decimal :tax_total, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0

      t.string :sat_uuid
      t.bigint :facturador_comprobante_id
      t.string :cancellation_motive
      t.string :replacement_uuid
      t.string :last_error_code
      t.text :last_error_message
      t.datetime :issued_at
      t.datetime :cancelled_at

      t.string :idempotency_key, null: false
      t.jsonb :payload_snapshot, null: false, default: {}
      t.jsonb :provider_response, null: false, default: {}

      t.timestamps
    end

    add_index :invoices, :idempotency_key, unique: true
    add_index :invoices, :sat_uuid, unique: true
    add_index :invoices, :facturador_comprobante_id, unique: true
    add_check_constraint :invoices, "kind IN ('ingreso', 'egreso', 'pago')", name: "check_invoices_kind"
    add_check_constraint :invoices, "status IN ('draft', 'queued', 'issued', 'cancel_pending', 'cancelled', 'failed')", name: "check_invoices_status"

    create_table :invoice_events do |t|
      t.references :invoice, null: false, foreign_key: true
      t.string :event_type, null: false
      t.string :provider_status
      t.string :provider_error_code
      t.text :provider_error_message
      t.jsonb :request_payload, null: false, default: {}
      t.jsonb :response_payload, null: false, default: {}
      t.references :created_by, polymorphic: true

      t.timestamps
    end

    add_index :invoice_events, [ :invoice_id, :created_at ]
    add_index :invoice_events, :event_type
  end
end
