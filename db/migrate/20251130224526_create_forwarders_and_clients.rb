class CreateForwardersAndClients < ActiveRecord::Migration[8.1]
  def change
    create_table :forwarders do |t|
      t.references :entity, null: false, foreign_key: true
      t.timestamps
    end
    add_index :forwarders, :entity_id, unique: true, if_not_exists: true

    create_table :clients do |t|
      t.references :entity, null: false, foreign_key: true
      t.timestamps
    end
    add_index :clients, :entity_id, unique: true, if_not_exists: true
  end
end
