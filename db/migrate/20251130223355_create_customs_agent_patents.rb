class CreateCustomsAgentPatents < ActiveRecord::Migration[8.1]
  def change
    create_table :customs_agent_patents do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :patent_number, null: false

      t.timestamps
    end

    add_index :customs_agent_patents, [ :entity_id, :patent_number ], unique: true, name: "index_patents_on_entity_and_number"
  end
end
