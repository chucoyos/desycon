class ChangeRevalidationAndDispatchDatesToDatetimes < ActiveRecord::Migration[8.1]
  def up
    change_column :bl_house_lines, :fecha_despacho, :datetime
    change_column :containers, :fecha_descarga, :datetime
    change_column :containers, :fecha_revalidacion_bl_master, :datetime
  end

  def down
    change_column :bl_house_lines, :fecha_despacho, :date
    change_column :containers, :fecha_descarga, :date
    change_column :containers, :fecha_revalidacion_bl_master, :date
  end
end
