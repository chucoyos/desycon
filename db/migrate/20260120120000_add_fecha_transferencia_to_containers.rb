class AddFechaTransferenciaToContainers < ActiveRecord::Migration[7.1]
  def change
    add_column :containers, :fecha_transferencia, :datetime
  end
end
