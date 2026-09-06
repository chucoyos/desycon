class CreateConsolidatorApiCredentials < ActiveRecord::Migration[8.1]
  def change
    create_table :consolidator_api_credentials do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :name, null: false
      t.string :key_prefix, null: false
      t.string :key_digest, null: false
      t.datetime :expires_at
      t.datetime :revoked_at
      t.datetime :last_used_at

      t.timestamps
    end

    add_index :consolidator_api_credentials, :key_digest, unique: true
    add_index :consolidator_api_credentials, :key_prefix
    add_index :consolidator_api_credentials, :revoked_at
  end
end
