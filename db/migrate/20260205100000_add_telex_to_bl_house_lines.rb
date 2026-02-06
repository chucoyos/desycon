class AddTelexToBlHouseLines < ActiveRecord::Migration[7.0]
  def change
    add_column :bl_house_lines, :telex, :boolean, default: false, null: false
    add_index :bl_house_lines, :telex
  end
end
