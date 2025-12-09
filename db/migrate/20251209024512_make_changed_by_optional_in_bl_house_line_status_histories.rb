class MakeChangedByOptionalInBlHouseLineStatusHistories < ActiveRecord::Migration[8.1]
  def change
    change_column_null :bl_house_line_status_histories, :changed_by_id, true
    change_column_null :bl_house_line_status_histories, :changed_by_type, true
  end
end
