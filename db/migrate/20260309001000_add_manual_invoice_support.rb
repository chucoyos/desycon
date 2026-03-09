class AddManualInvoiceSupport < ActiveRecord::Migration[8.1]
  def change
    change_table :invoices, bulk: true do |t|
      t.references :customs_agent, foreign_key: { to_table: :entities }
      t.change_null :invoiceable_id, true
      t.change_null :invoiceable_type, true
    end

    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true
      t.references :service_catalog, null: false, foreign_key: true
      t.integer :position, null: false, default: 0
      t.string :description, null: false
      t.string :sat_clave_prod_serv, null: false
      t.string :sat_clave_unidad, null: false
      t.string :sat_objeto_imp, null: false
      t.decimal :sat_tasa_iva, precision: 6, scale: 4, null: false, default: 0.16
      t.decimal :quantity, precision: 12, scale: 3, null: false, default: 1
      t.decimal :unit_price, precision: 12, scale: 2, null: false, default: 0
      t.decimal :subtotal, precision: 12, scale: 2, null: false, default: 0
      t.decimal :tax_amount, precision: 12, scale: 2, null: false, default: 0
      t.decimal :total, precision: 12, scale: 2, null: false, default: 0
      t.timestamps
    end

    add_index :invoice_line_items, [ :invoice_id, :position ]
  end
end
