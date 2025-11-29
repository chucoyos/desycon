class CreateFiscalProfiles < ActiveRecord::Migration[8.1]
  def change
    create_table :fiscal_profiles do |t|
      t.references :profileable, polymorphic: true, null: false, index: false
      t.string :razon_social, null: false
      t.string :rfc, null: false
      t.string :regimen, null: false
      t.string :uso_cfdi
      t.string :forma_pago
      t.string :metodo_pago

      t.timestamps
    end

    add_index :fiscal_profiles, :rfc
    add_index :fiscal_profiles, [ :profileable_type, :profileable_id ], unique: true, name: 'index_fiscal_profiles_on_profileable'
  end
end
