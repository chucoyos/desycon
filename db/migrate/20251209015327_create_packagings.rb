class CreatePackagings < ActiveRecord::Migration[8.1]
  def change
    create_table :packagings do |t|
      t.string :nombre

      t.timestamps
    end
  end
end
