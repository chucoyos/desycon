class CreateBlHouseLineServices < ActiveRecord::Migration[8.1]
  def change
    create_table :bl_house_line_services do |t|
      t.references :bl_house_line, null: false, foreign_key: true
      t.references :service_catalog, null: false, foreign_key: true
      t.references :billed_to_entity, foreign_key: { to_table: :entities }
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "MXN"
      t.date :fecha_programada
      t.text :observaciones
      t.string :factura

      t.timestamps
    end

    add_index :bl_house_line_services, :factura
    add_index :bl_house_line_services, :fecha_programada
  end
end
