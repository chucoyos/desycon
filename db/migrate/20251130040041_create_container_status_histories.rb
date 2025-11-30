class CreateContainerStatusHistories < ActiveRecord::Migration[8.1]
  def change
    create_table :container_status_histories do |t|
      t.references :container, null: false, foreign_key: true
      t.string :status, null: false
      t.datetime :fecha_actualizacion, null: false
      t.text :observaciones
      t.references :user, foreign_key: true

      t.timestamps
    end

    add_index :container_status_histories, :status
    add_index :container_status_histories, :fecha_actualizacion
    add_index :container_status_histories, [ :container_id, :fecha_actualizacion ],
              name: "index_status_histories_on_container_and_date"
  end
end
