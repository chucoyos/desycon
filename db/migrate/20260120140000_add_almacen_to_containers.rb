class AddAlmacenToContainers < ActiveRecord::Migration[7.1]
  def change
    add_column :containers, :almacen, :string
  end
end
