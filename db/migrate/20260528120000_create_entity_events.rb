class CreateEntityEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :entity_events do |t|
      t.references :entity, null: false, foreign_key: true
      t.references :user, null: true, foreign_key: true
      t.string :event_type, null: false
      t.jsonb :changed_fields_json, null: false, default: {}
      t.jsonb :snapshot_json, null: false, default: {}

      t.timestamps
    end

    add_index :entity_events, [ :entity_id, :created_at ]
    add_index :entity_events, :event_type
  end
end
