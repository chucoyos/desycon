class CreateInvoicePaymentEvidences < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_payment_evidences do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :customs_agent, null: false, foreign_key: { to_table: :entities }
      t.references :submitted_by, null: false, foreign_key: { to_table: :users }
      t.references :invoice_payment, null: true, foreign_key: true

      t.string :reference, null: false
      t.string :tracking_key
      t.string :status, null: false, default: "pending"
      t.text :review_comment

      t.timestamps
    end

    add_check_constraint :invoice_payment_evidences,
      "status IN ('pending','linked','rejected')",
      name: "check_invoice_payment_evidences_status"

    add_index :invoice_payment_evidences, :status
  end
end
