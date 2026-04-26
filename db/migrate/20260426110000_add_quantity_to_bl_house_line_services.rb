class AddQuantityToBlHouseLineServices < ActiveRecord::Migration[8.0]
  def change
    add_column :bl_house_line_services, :quantity, :integer
  end
end
