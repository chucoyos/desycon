class RenameContKeyToEjecutivoInContainers < ActiveRecord::Migration[8.1]
  def change
    rename_column :containers, :cont_key, :ejecutivo
  end
end
