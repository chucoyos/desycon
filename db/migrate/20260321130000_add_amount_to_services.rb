class AddAmountToServices < ActiveRecord::Migration[8.0]
  def up
    add_column :container_services, :amount, :decimal, precision: 12, scale: 2
    add_column :bl_house_line_services, :amount, :decimal, precision: 12, scale: 2

    ContainerService.reset_column_information
    BlHouseLineService.reset_column_information

    ContainerService.includes(:service_catalog).find_each do |service|
      service.update_columns(amount: service.service_catalog.amount)
    end

    BlHouseLineService.includes(:service_catalog).find_each do |service|
      service.update_columns(amount: service.service_catalog.amount)
    end

    change_column_null :container_services, :amount, false
    change_column_null :bl_house_line_services, :amount, false
  end

  def down
    remove_column :container_services, :amount
    remove_column :bl_house_line_services, :amount
  end
end
