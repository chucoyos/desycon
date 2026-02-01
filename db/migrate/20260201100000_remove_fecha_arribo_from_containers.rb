class RemoveFechaArriboFromContainers < ActiveRecord::Migration[8.1]
  def change
    if index_exists?(:containers, :fecha_arribo)
      remove_index :containers, :fecha_arribo
    end

    remove_column :containers, :fecha_arribo, :date
  end
end
