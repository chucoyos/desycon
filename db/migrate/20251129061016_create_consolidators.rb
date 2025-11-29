class CreateConsolidators < ActiveRecord::Migration[8.1]
  def change
    create_table :consolidators do |t|
      t.string :name, null: false

      t.timestamps
    end

    add_index :consolidators, :name, unique: true
  end
end
