class RenameScacCodeToIsoCodeInShippingLines < ActiveRecord::Migration[8.1]
  def change
    rename_column :shipping_lines, :scac_code, :iso_code
  end
end
