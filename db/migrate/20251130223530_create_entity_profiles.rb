class CreateEntityProfiles < ActiveRecord::Migration[8.1]
  def change
    # consolidators ya fue creada en MigrateConsolidatorsToEntities

    create_table :forwarders do |t|
      t.references :entity, null: false, foreign_key: true

      t.timestamps
    end
    add_index :forwarders, :entity_id, unique: true unless index_exists?(:forwarders, :entity_id)

    create_table :clients do |t|
      t.references :entity, null: false, foreign_key: true

      t.timestamps
    end
    add_index :clients, :entity_id, unique: true unless index_exists?(:clients, :entity_id)
  end
end
