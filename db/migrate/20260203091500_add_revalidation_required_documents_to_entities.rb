class AddRevalidationRequiredDocumentsToEntities < ActiveRecord::Migration[7.1]
  def change
    change_table :entities, bulk: true do |t|
      t.boolean :requires_bl_endosado_documento, default: true, null: false
      t.boolean :requires_liberacion_documento, default: true, null: false
      t.boolean :requires_encomienda_documento, default: true, null: false
      t.boolean :requires_pago_documento, default: true, null: false
    end
  end
end