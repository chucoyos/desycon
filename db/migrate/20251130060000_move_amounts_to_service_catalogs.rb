class MoveAmountsToServiceCatalogs < ActiveRecord::Migration[8.1]
  class MigrationServiceCatalog < ApplicationRecord
    self.table_name = "service_catalogs"
  end

  class MigrationContainerService < ApplicationRecord
    self.table_name = "container_services"
  end

  class MigrationBlHouseLineService < ApplicationRecord
    self.table_name = "bl_house_line_services"
  end

  def up
    add_column :service_catalogs, :amount, :decimal, precision: 12, scale: 2 unless column_exists?(:service_catalogs, :amount)
    add_column :service_catalogs, :currency, :string, null: false, default: "MXN" unless column_exists?(:service_catalogs, :currency)

    MigrationServiceCatalog.reset_column_information
    MigrationContainerService.reset_column_information
    MigrationBlHouseLineService.reset_column_information

    say_with_time "Backfilling catalog amounts from existing services" do
      MigrationServiceCatalog.find_each do |catalog|
        next if catalog.amount.present?

        from_container = MigrationContainerService.where(service_catalog_id: catalog.id).where.not(amount: nil).limit(1).pluck(:amount).first
        from_bl = MigrationBlHouseLineService.where(service_catalog_id: catalog.id).where.not(amount: nil).limit(1).pluck(:amount).first
        amount_value = from_container || from_bl

        catalog.update_columns(amount: amount_value || 0.01, currency: "MXN")
      end
    end

    change_column_null :service_catalogs, :amount, false

    remove_column :container_services, :amount if column_exists?(:container_services, :amount)
    remove_column :container_services, :currency if column_exists?(:container_services, :currency)
    remove_column :bl_house_line_services, :amount if column_exists?(:bl_house_line_services, :amount)
    remove_column :bl_house_line_services, :currency if column_exists?(:bl_house_line_services, :currency)
  end

  def down
    add_column :container_services, :amount, :decimal, precision: 12, scale: 2 unless column_exists?(:container_services, :amount)
    add_column :container_services, :currency, :string, null: false, default: "MXN" unless column_exists?(:container_services, :currency)
    add_column :bl_house_line_services, :amount, :decimal, precision: 12, scale: 2 unless column_exists?(:bl_house_line_services, :amount)
    add_column :bl_house_line_services, :currency, :string, null: false, default: "MXN" unless column_exists?(:bl_house_line_services, :currency)

    MigrationServiceCatalog.reset_column_information
    MigrationContainerService.reset_column_information
    MigrationBlHouseLineService.reset_column_information

    say_with_time "Restoring service amounts from catalog" do
      MigrationContainerService.find_each do |service|
        catalog = MigrationServiceCatalog.find_by(id: service.service_catalog_id)
        service.update_columns(amount: catalog&.amount, currency: catalog&.currency || "MXN")
      end

      MigrationBlHouseLineService.find_each do |service|
        catalog = MigrationServiceCatalog.find_by(id: service.service_catalog_id)
        service.update_columns(amount: catalog&.amount, currency: catalog&.currency || "MXN")
      end
    end

    remove_column :service_catalogs, :amount if column_exists?(:service_catalogs, :amount)
    remove_column :service_catalogs, :currency if column_exists?(:service_catalogs, :currency)
  end
end
