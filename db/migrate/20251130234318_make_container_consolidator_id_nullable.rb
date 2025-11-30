class MakeContainerConsolidatorIdNullable < ActiveRecord::Migration[8.1]
  def change
    # Make consolidator_id nullable since we're transitioning to consolidator_entity_id
    change_column_null :containers, :consolidator_id, true

    # Remove foreign key constraint to consolidators_old (deprecated table)
    remove_foreign_key :containers, column: :consolidator_id if foreign_key_exists?(:containers, column: :consolidator_id)
  end
end
