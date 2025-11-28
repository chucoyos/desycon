class CreateVessels < ActiveRecord::Migration[8.1]
  def change
    create_table :vessels do |t|
      t.string :name, null: false
      t.references :shipping_line, null: false, foreign_key: true

      t.timestamps
    end

    add_index :vessels, [ :shipping_line_id, :name ], name: 'index_vessels_on_shipping_line_and_name'
    add_index :vessels, :name, unique: true
  end
end
