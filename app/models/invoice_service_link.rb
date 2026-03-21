class InvoiceServiceLink < ApplicationRecord
  belongs_to :invoice
  belongs_to :serviceable, polymorphic: true

  validates :invoice_id, uniqueness: { scope: [ :serviceable_type, :serviceable_id ] }
end
