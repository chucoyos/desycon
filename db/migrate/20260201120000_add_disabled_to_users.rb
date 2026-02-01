class AddDisabledToUsers < ActiveRecord::Migration[7.1]
  def change
    add_column :users, :disabled, :boolean, default: false, null: false
    add_index :users, :disabled
  end
end
