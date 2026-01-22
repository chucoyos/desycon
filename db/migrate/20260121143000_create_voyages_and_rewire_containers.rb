class CreateVoyagesAndRewireContainers < ActiveRecord::Migration[8.1]
  def up
    create_table :voyages do |t|
      t.string :viaje, null: false
      t.string :voyage_type, null: false
      t.date :ata
      t.date :eta
      t.date :inicio_operacion
      t.date :fin_operacion
      t.references :origin_port, foreign_key: { to_table: :ports }
      t.references :destination_port, foreign_key: { to_table: :ports }
      t.references :vessel, null: false, foreign_key: true

      t.timestamps
    end

    add_index :voyages, [ :vessel_id, :viaje ], unique: true

    add_reference :containers, :voyage, foreign_key: true

    remove_foreign_key :containers, column: :port_id if foreign_key_exists?(:containers, column: :port_id)
    remove_foreign_key :containers, column: :destination_port_id if foreign_key_exists?(:containers, column: :destination_port_id)

    remove_column :containers, :port_id
    remove_column :containers, :destination_port_id
    remove_column :containers, :viaje
  end

  def down
    add_column :containers, :port_id, :bigint
    add_column :containers, :destination_port_id, :bigint
    add_column :containers, :viaje, :string

    add_foreign_key :containers, :ports, column: :port_id
    add_foreign_key :containers, :ports, column: :destination_port_id

    remove_reference :containers, :voyage, foreign_key: true

    drop_table :voyages
  end
end
