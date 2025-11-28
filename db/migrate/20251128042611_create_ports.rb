class CreatePorts < ActiveRecord::Migration[8.1]
  def change
    create_table :ports do |t|
      t.string :name, null: false
      t.string :code, null: false
      t.string :country_code, null: false

      t.timestamps
    end

    add_index :ports, :code, unique: true
    add_index :ports, :country_code
    add_index :ports, [ :country_code, :name ]
  end
end
