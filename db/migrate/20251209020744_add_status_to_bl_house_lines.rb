class AddStatusToBlHouseLines < ActiveRecord::Migration[8.1]
  def change
    add_column :bl_house_lines, :status, :string
  end
end
