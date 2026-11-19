class AddTransportDetailsToBlHouseLineServiceRequests < ActiveRecord::Migration[8.1]
  def change
    add_column :bl_house_line_service_requests, :numero_economico, :string
    add_column :bl_house_line_service_requests, :transportista, :string
    add_column :bl_house_line_service_requests, :operador, :string
    add_column :bl_house_line_service_requests, :placas, :string
  end
end
