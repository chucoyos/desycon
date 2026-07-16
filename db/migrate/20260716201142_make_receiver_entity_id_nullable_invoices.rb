class MakeReceiverEntityIdNullableInvoices < ActiveRecord::Migration[8.1]
  def change
    change_column_null :invoices, :receiver_entity_id, true
  end
end
