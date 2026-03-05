class AddSatFieldsToServiceCatalogs < ActiveRecord::Migration[8.1]
  def change
    add_column :service_catalogs, :sat_clave_prod_serv, :string
    add_column :service_catalogs, :sat_clave_unidad, :string
    add_column :service_catalogs, :sat_objeto_imp, :string, default: "02", null: false
    add_column :service_catalogs, :sat_tasa_iva, :decimal, precision: 6, scale: 4, default: 0.16, null: false

    add_index :service_catalogs, :sat_clave_prod_serv
    add_index :service_catalogs, :sat_clave_unidad
  end
end
