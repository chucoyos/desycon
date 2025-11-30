class CreateContainerServices < ActiveRecord::Migration[8.1]
  def change
    create_table :container_services do |t|
      t.references :container, null: false, foreign_key: true
      t.string :cliente, null: false
      t.decimal :cantidad, precision: 10, scale: 2, null: false
      t.string :servicio, null: false
      t.date :fecha_programada
      t.text :observaciones
      t.string :referencia
      t.string :factura

      t.timestamps
    end

    add_index :container_services, :cliente
    add_index :container_services, :servicio
    add_index :container_services, :fecha_programada
    add_index :container_services, :factura
  end
end
