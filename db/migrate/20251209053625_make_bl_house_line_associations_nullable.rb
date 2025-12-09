class MakeBlHouseLineAssociationsNullable < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bl_house_lines, :customs_agent_id, true
    change_column_null :bl_house_lines, :client_id, true
    change_column_null :bl_house_lines, :container_id, true
    change_column_null :bl_house_lines, :packaging_id, true
  end
end
