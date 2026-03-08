class AddCreationOriginToAutoBillableServices < ActiveRecord::Migration[8.1]
  def change
    add_column :container_services, :creation_origin, :string
    add_column :bl_house_line_services, :creation_origin, :string

    add_index :container_services, :creation_origin
    add_index :bl_house_line_services, :creation_origin
  end
end
