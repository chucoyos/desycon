class AddFechaTentativaDesconsolidacionToContainers < ActiveRecord::Migration[7.0]
  def change
    add_column :containers, :fecha_tentativa_desconsolidacion, :date
    add_index :containers, :fecha_tentativa_desconsolidacion
  end
end
