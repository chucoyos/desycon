class CreateBlHouseLines < ActiveRecord::Migration[8.1]
  def change
    create_table :bl_house_lines do |t|
      t.string :blhouse
      t.integer :partida
      t.integer :cantidad
      t.text :contiene
      t.text :marcas
      t.decimal :peso
      t.decimal :volumen
      t.string :status
      t.references :customs_agent, null: false, foreign_key: { to_table: :entities }
      t.references :client, null: false, foreign_key: true
      t.references :container, null: false, foreign_key: true
      t.references :packaging, null: false, foreign_key: true

      t.timestamps
    end
  end
end
