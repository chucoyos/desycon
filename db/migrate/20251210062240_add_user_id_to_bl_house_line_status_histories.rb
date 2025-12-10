class AddUserIdToBlHouseLineStatusHistories < ActiveRecord::Migration[8.1]
  def change
    add_column :bl_house_line_status_histories, :user_id, :integer
    add_index :bl_house_line_status_histories, :user_id

    # Migrate existing data from polymorphic association
    reversible do |dir|
      dir.up do
        execute <<-SQL
          UPDATE bl_house_line_status_histories
          SET user_id = changed_by_id
          WHERE changed_by_type = 'User' AND changed_by_id IS NOT NULL
        SQL
      end
    end
  end
end
