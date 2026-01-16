class AddHiddenFromCustomsAgentToBlHouseLines < ActiveRecord::Migration[7.1]
  def change
    add_column :bl_house_lines, :hidden_from_customs_agent, :boolean, default: false, null: false
    add_index :bl_house_lines, :hidden_from_customs_agent
  end
end
