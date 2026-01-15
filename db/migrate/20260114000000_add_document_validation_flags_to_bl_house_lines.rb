class AddDocumentValidationFlagsToBlHouseLines < ActiveRecord::Migration[7.0]
  def change
    add_column :bl_house_lines, :bl_endosado_documento_validated, :boolean, default: false, null: false
    add_column :bl_house_lines, :liberacion_documento_validated, :boolean, default: false, null: false
    add_column :bl_house_lines, :encomienda_documento_validated, :boolean, default: false, null: false
    add_column :bl_house_lines, :pago_documento_validated, :boolean, default: false, null: false
  end
end
