class AddTransferenciaNoAplicaToContainers < ActiveRecord::Migration[8.1]
  def change
    add_column :containers, :transferencia_no_aplica, :boolean, null: false, default: false
    add_index :containers, :transferencia_no_aplica
  end
end
