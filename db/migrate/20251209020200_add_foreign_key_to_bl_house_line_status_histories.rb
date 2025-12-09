class AddForeignKeyToBlHouseLineStatusHistories < ActiveRecord::Migration[8.1]
  def change
    add_foreign_key :bl_house_line_status_histories, :bl_house_lines
  end
end
