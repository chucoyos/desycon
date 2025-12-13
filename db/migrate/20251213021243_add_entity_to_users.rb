class AddEntityToUsers < ActiveRecord::Migration[8.1]
  def change
    add_reference :users, :entity, foreign_key: true
  end
end
