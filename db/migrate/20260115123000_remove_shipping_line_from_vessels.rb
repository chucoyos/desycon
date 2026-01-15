class RemoveShippingLineFromVessels < ActiveRecord::Migration[7.1]
  def change
    # Remove foreign key if present
    remove_foreign_key :vessels, :shipping_lines if foreign_key_exists?(:vessels, :shipping_lines)

    # Drop indexes that include shipping_line_id
    remove_index :vessels, name: "index_vessels_on_shipping_line_and_name" if index_exists?(:vessels, [ :shipping_line_id, :name ], name: "index_vessels_on_shipping_line_and_name")
    remove_index :vessels, name: "index_vessels_on_shipping_line_id" if index_exists?(:vessels, :shipping_line_id, name: "index_vessels_on_shipping_line_id")

    # Drop the column
    remove_column :vessels, :shipping_line_id, :bigint
  end
end
