class AddContainerTypeAndSizeToContainers < ActiveRecord::Migration[8.1]
  def change
    add_column :containers, :container_type, :string
    add_column :containers, :size_ft, :string

    add_index :containers, :container_type
    add_index :containers, :size_ft
  end
end
