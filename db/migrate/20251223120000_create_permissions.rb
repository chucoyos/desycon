class CreatePermissions < ActiveRecord::Migration[7.2]
  def change
    create_table :permissions do |t|
      t.string :name, null: false
      t.string :key, null: false
      t.string :description

      t.timestamps
    end

    add_index :permissions, :key, unique: true
  end
end
