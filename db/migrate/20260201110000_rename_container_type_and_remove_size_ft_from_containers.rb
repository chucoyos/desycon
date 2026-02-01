class RenameContainerTypeAndRemoveSizeFtFromContainers < ActiveRecord::Migration[7.1]
  def change
    if index_name_exists?(:containers, "index_containers_on_container_type")
      rename_index :containers, "index_containers_on_container_type", "index_containers_on_type_size"
    end

    rename_column :containers, :container_type, :type_size

    if index_name_exists?(:containers, :size_ft)
      remove_index :containers, :size_ft
    end

    remove_column :containers, :size_ft, :string
  end
end
