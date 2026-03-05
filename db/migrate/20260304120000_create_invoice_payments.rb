class CreateInvoicePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_payments do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :complement_invoice, foreign_key: { to_table: :invoices }

      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "MXN"
      t.datetime :paid_at, null: false
      t.string :payment_method, null: false, default: "03"
      t.string :reference
      t.string :status, null: false, default: "registered"
      t.text :notes

      t.timestamps
    end

    add_index :invoice_payments, :status
    add_check_constraint :invoice_payments, "status IN ('registered', 'complement_queued', 'complement_issued', 'failed')", name: "check_invoice_payments_status"
  end
end
