class AddRoleKindToEntities < ActiveRecord::Migration[8.1]
  ROLE_KINDS = %w[customs_agent consolidator customs_broker client forwarder].freeze

  def up
    add_column :entities, :role_kind, :string
    add_index :entities, :role_kind

    execute <<~SQL.squish
      UPDATE entities
      SET role_kind = CASE
        WHEN is_customs_agent = TRUE THEN 'customs_agent'
        WHEN is_consolidator = TRUE THEN 'consolidator'
        WHEN is_customs_broker = TRUE THEN 'customs_broker'
        WHEN is_client = TRUE THEN 'client'
        WHEN is_forwarder = TRUE THEN 'forwarder'
        ELSE NULL
      END
    SQL

    add_check_constraint :entities,
      "role_kind IS NULL OR role_kind IN ('customs_agent', 'consolidator', 'customs_broker', 'client', 'forwarder')",
      name: "check_entities_role_kind"
  end

  def down
    remove_check_constraint :entities, name: "check_entities_role_kind"
    remove_index :entities, :role_kind
    remove_column :entities, :role_kind
  end
end
