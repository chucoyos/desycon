class CreateAddresses < ActiveRecord::Migration[8.1]
  def change
    create_table :addresses do |t|
      t.references :addressable, polymorphic: true, null: false, index: false
      t.string :tipo # 'fiscal', 'envio', 'almacen', etc.
      t.string :pais, null: false
      t.string :codigo_postal, null: false
      t.string :estado, null: false
      t.string :municipio
      t.string :localidad
      t.string :colonia
      t.string :calle
      t.string :numero_exterior
      t.string :numero_interior
      t.string :email, null: false

      t.timestamps
    end

    add_index :addresses, :codigo_postal
    add_index :addresses, [ :addressable_type, :addressable_id, :tipo ], name: 'index_addresses_on_addressable_and_tipo'
  end
end
