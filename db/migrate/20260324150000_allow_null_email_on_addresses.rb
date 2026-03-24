class AllowNullEmailOnAddresses < ActiveRecord::Migration[8.1]
  def change
    change_column_null :addresses, :email, true
  end
end
