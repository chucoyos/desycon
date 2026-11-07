class CreateBlHouseLineServiceRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :bl_house_line_service_requests do |t|
      t.references :bl_house_line, null: false, foreign_key: true
      t.references :service_catalog, null: false, foreign_key: true
      t.references :requester, null: false, foreign_key: { to_table: :users }
      t.references :customs_agent, null: false, foreign_key: { to_table: :entities }
      t.references :bl_house_line_service, foreign_key: true, index: { unique: true }
      t.date :requested_date, null: false
      t.date :scheduled_date
      t.time :scheduled_time
      t.string :status, null: false, default: "pending"
      t.datetime :executed_at
      t.text :review_notes
      t.timestamps
    end

    create_table :bl_house_line_service_request_events do |t|
      t.references :bl_house_line_service_request, null: false, foreign_key: true, index: { name: "index_bl_service_request_events_on_request_id" }
      t.references :actor, null: false, foreign_key: { to_table: :users }
      t.string :action, null: false
      t.date :scheduled_date
      t.time :scheduled_time
      t.text :notes
      t.timestamps
    end
  end
end
