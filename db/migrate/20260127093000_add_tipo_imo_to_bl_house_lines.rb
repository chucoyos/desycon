class AddTipoImoToBlHouseLines < ActiveRecord::Migration[7.1]
  def change
    add_column :bl_house_lines, :tipo_imo, :string
  end
end
