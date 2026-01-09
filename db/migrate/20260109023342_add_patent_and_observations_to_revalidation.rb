class AddPatentAndObservationsToRevalidation < ActiveRecord::Migration[8.1]
  def change
    add_reference :bl_house_lines, :customs_agent_patent, null: true, foreign_key: true
    add_column :bl_house_line_status_histories, :observations, :text
  end
end
