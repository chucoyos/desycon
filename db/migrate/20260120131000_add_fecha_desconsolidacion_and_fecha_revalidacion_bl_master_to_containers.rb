class AddFechaDesconsolidacionAndFechaRevalidacionBlMasterToContainers < ActiveRecord::Migration[7.1]
  def change
    add_column :containers, :fecha_desconsolidacion, :date
    add_column :containers, :fecha_revalidacion_bl_master, :date
  end
end
