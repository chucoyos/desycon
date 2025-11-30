class CreateContainers < ActiveRecord::Migration[8.1]
  def change
    create_table :containers do |t|
      # Número único del contenedor
      t.string :number, null: false

      # Status del contenedor: activo, validar_documentos, desconsolidado
      t.string :status, null: false, default: "activo"

      # Tipo de maniobra: importacion, exportacion
      t.string :tipo_maniobra, null: false

      # Relaciones
      t.references :consolidator, null: false, foreign_key: true
      t.references :shipping_line, null: false, foreign_key: true
      t.references :vessel, foreign_key: true

      # Datos del contenedor
      t.string :bl_master
      t.date :fecha_arribo
      t.string :puerto_origen
      t.string :viaje
      t.string :recinto # SSA, FRIMAN, etc
      t.string :archivo_nr
      t.string :sello
      t.string :cont_key

      t.timestamps
    end

    add_index :containers, :number, unique: true
    add_index :containers, :status
    add_index :containers, :tipo_maniobra
    add_index :containers, :fecha_arribo
  end
end
