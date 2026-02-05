class AddTentativaTurnoToContainers < ActiveRecord::Migration[7.0]
  def change
    add_column :containers, :tentativa_turno, :integer
    add_index :containers, :tentativa_turno
  end
end
