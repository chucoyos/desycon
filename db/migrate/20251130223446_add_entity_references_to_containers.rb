class AddEntityReferencesToContainers < ActiveRecord::Migration[8.1]
  def change
    # Agregar referencia a entity en containers
    add_reference :containers, :consolidator_entity, foreign_key: { to_table: :entities }

    # Agregar referencia a entity en container_services para facturación
    add_reference :container_services, :billed_to_entity, foreign_key: { to_table: :entities }
  end
end
