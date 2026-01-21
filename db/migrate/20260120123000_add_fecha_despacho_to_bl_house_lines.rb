class AddFechaDespachoToBlHouseLines < ActiveRecord::Migration[7.1]
  def change
    add_column :bl_house_lines, :fecha_despacho, :date
  end
end
