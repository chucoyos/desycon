class RemoveLegacyRoleFlagsFromEntities < ActiveRecord::Migration[8.1]
  def up
    remove_column :entities, :is_consolidator, :boolean
    remove_column :entities, :is_customs_agent, :boolean
    remove_column :entities, :is_customs_broker, :boolean
    remove_column :entities, :is_forwarder, :boolean
    remove_column :entities, :is_client, :boolean
  end

  def down
    add_column :entities, :is_consolidator, :boolean, default: false
    add_column :entities, :is_customs_agent, :boolean, default: false
    add_column :entities, :is_customs_broker, :boolean, default: false, null: false
    add_column :entities, :is_forwarder, :boolean, default: false
    add_column :entities, :is_client, :boolean, default: false

    execute <<~SQL.squish
      UPDATE entities
      SET
        is_consolidator = (role_kind = 'consolidator'),
        is_customs_agent = (role_kind = 'customs_agent'),
        is_customs_broker = (role_kind = 'customs_broker'),
        is_forwarder = (role_kind = 'forwarder'),
        is_client = (role_kind = 'client')
    SQL
  end
end
