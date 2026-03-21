class CreateInvoiceServiceLinks < ActiveRecord::Migration[8.0]
  def change
    create_table :invoice_service_links do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :serviceable, polymorphic: true, null: false

      t.timestamps
    end

    add_index :invoice_service_links, [ :invoice_id, :serviceable_type, :serviceable_id ], unique: true, name: "index_invoice_service_links_uniqueness"
  end
end
