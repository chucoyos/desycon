class CreateBlHouseLineStatusHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :bl_house_line_status_histories do |t|
      t.references :bl_house_line, null: true
      t.string :status
      t.string :previous_status
      t.datetime :changed_at
      t.references :changed_by, polymorphic: true, null: false

      t.timestamps
    end
  end
end
