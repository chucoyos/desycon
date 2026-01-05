class ChangeContainerNumberUniquenessScope < ActiveRecord::Migration[8.1]
  def change
    remove_index :containers, :number
    add_index :containers, [ :number, :bl_master ], unique: true
  end
end
