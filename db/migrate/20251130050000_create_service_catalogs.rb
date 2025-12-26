class CreateServiceCatalogs < ActiveRecord::Migration[8.1]
  def change
    create_table :service_catalogs do |t|
      t.string :name, null: false
      t.string :applies_to, null: false
      t.string :code
      t.boolean :active, null: false, default: true

      t.timestamps
    end

    add_index :service_catalogs, [ :applies_to, :name ], unique: true
    add_index :service_catalogs, :code, unique: true
  end
end
