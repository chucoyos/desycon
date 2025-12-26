class MigrateContainerServicesToCatalog < ActiveRecord::Migration[8.1]
  class MigrationContainerService < ApplicationRecord
    self.table_name = "container_services"
  end

  class MigrationServiceCatalog < ApplicationRecord
    self.table_name = "service_catalogs"
  end

  def up
    add_reference :container_services, :service_catalog, foreign_key: true unless column_exists?(:container_services, :service_catalog_id)
    add_reference :container_services, :billed_to_entity, foreign_key: { to_table: :entities } unless column_exists?(:container_services, :billed_to_entity_id)
    add_column :container_services, :amount, :decimal, precision: 12, scale: 2
    add_column :container_services, :currency, :string, null: false, default: "MXN"

    MigrationContainerService.reset_column_information
    MigrationServiceCatalog.reset_column_information

    say_with_time "Migrating container services to catalog" do
      MigrationContainerService.find_each do |service|
        catalog = MigrationServiceCatalog.find_or_create_by!(name: service.servicio.presence || "Servicio sin nombre", applies_to: "container")
        service.update_columns(
          service_catalog_id: catalog.id,
          amount: service.cantidad,
          currency: "MXN"
        )
      end
    end

    change_column_null :container_services, :service_catalog_id, false
    change_column_null :container_services, :amount, false

    remove_column :container_services, :cliente, :string
    remove_column :container_services, :cantidad, :decimal, precision: 10, scale: 2
    remove_column :container_services, :servicio, :string
    remove_column :container_services, :referencia, :string
  end

  def down
    add_column :container_services, :cliente, :string
    add_column :container_services, :cantidad, :decimal, precision: 10, scale: 2
    add_column :container_services, :servicio, :string
    add_column :container_services, :referencia, :string

    MigrationContainerService.reset_column_information
    MigrationServiceCatalog.reset_column_information

    say_with_time "Reverting container services to legacy columns" do
      MigrationContainerService.find_each do |service|
        catalog_name = MigrationServiceCatalog.find_by(id: service.service_catalog_id)&.name
        service.update_columns(
          cliente: "Desconocido",
          cantidad: service.amount,
          servicio: catalog_name,
          referencia: nil
        )
      end
    end

    remove_reference :container_services, :service_catalog, foreign_key: true
    remove_reference :container_services, :billed_to_entity, foreign_key: true
    remove_column :container_services, :amount
    remove_column :container_services, :currency
  end
end
