class CreateInvoicePaymentEvidenceLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_payment_evidence_links do |t|
      t.references :invoice_payment_evidence, null: false, foreign_key: true
      t.references :invoice, null: false, foreign_key: true

      t.timestamps
    end

    add_index :invoice_payment_evidence_links,
      [ :invoice_payment_evidence_id, :invoice_id ],
      unique: true,
      name: "idx_unique_invoice_payment_evidence_links"
  end
end
