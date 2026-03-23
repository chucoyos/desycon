class InvoicePaymentEvidenceLink < ApplicationRecord
  belongs_to :invoice_payment_evidence
  belongs_to :invoice

  validates :invoice_id, uniqueness: { scope: :invoice_payment_evidence_id }
end
