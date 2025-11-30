class CreateEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :entities do |t|
      t.string :name, null: false
      t.boolean :is_consolidator, default: false
      t.boolean :is_customs_agent, default: false
      t.boolean :is_forwarder, default: false
      t.boolean :is_client, default: false

      t.timestamps
    end

    add_index :entities, :name
  end
end
