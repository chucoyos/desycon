class AddCustomsAgentIdToEntities < ActiveRecord::Migration[8.1]
  def change
    add_reference :entities, :customs_agent, null: true, foreign_key: { to_table: :entities }
  end
end
