class AddConsolidatorIncrementalSyncIndexes < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    add_index :containers,
              [ :consolidator_entity_id, :updated_at, :id ],
              name: "index_containers_on_consolidator_entity_updated_id",
              algorithm: :concurrently,
              if_not_exists: true

    add_index :bl_house_lines,
              [ :container_id, :updated_at, :id ],
              name: "index_bl_house_lines_on_container_updated_id",
              algorithm: :concurrently,
              if_not_exists: true
  end

  def down
    remove_index :containers,
                 name: "index_containers_on_consolidator_entity_updated_id",
                 algorithm: :concurrently,
                 if_exists: true

    remove_index :bl_house_lines,
                 name: "index_bl_house_lines_on_container_updated_id",
                 algorithm: :concurrently,
                 if_exists: true
  end
end
