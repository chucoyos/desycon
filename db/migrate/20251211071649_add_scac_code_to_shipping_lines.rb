class AddScacCodeToShippingLines < ActiveRecord::Migration[8.1]
  def change
    add_column :shipping_lines, :scac_code, :string
  end
end
