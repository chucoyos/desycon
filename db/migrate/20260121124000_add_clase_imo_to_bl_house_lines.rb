class AddClaseImoToBlHouseLines < ActiveRecord::Migration[7.1]
  def change
    add_column :bl_house_lines, :clase_imo, :string
  end
end
