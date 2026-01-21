class AddFechaDescargaToContainers < ActiveRecord::Migration[7.1]
  def change
    add_column :containers, :fecha_descarga, :date
  end
end
