class ChangePortOrigenToReferenceInContainers < ActiveRecord::Migration[8.1]
  def change
    # Remover la columna puerto_origen de tipo string
    remove_column :containers, :puerto_origen, :string
    
    # Agregar la referencia a ports
    add_reference :containers, :port, foreign_key: true, index: true
  end
end
