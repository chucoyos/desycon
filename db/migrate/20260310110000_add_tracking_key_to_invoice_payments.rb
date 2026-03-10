class AddTrackingKeyToInvoicePayments < ActiveRecord::Migration[8.1]
  def change
    add_column :invoice_payments, :tracking_key, :string
    add_index :invoice_payments, :tracking_key
  end
end
