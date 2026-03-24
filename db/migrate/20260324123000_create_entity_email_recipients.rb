class CreateEntityEmailRecipients < ActiveRecord::Migration[8.1]
  def up
    create_table :entity_email_recipients do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :email, null: false
      t.boolean :active, null: false, default: true
      t.boolean :primary_recipient, null: false, default: false
      t.integer :position, null: false, default: 0

      t.timestamps
    end

    add_index :entity_email_recipients, [ :entity_id, :email ], unique: true
    add_index :entity_email_recipients, [ :entity_id, :active ]
    add_index :entity_email_recipients, [ :entity_id, :primary_recipient ]

    backfill_from_entity_fiscal_addresses
  end

  def down
    drop_table :entity_email_recipients
  end

  private

  def backfill_from_entity_fiscal_addresses
    execute <<~SQL.squish
      INSERT INTO entity_email_recipients (entity_id, email, active, primary_recipient, position, created_at, updated_at)
      SELECT entities.id,
             LOWER(TRIM(addresses.email)) AS email,
             TRUE AS active,
             TRUE AS primary_recipient,
             0 AS position,
             NOW(),
             NOW()
      FROM entities
      INNER JOIN addresses
        ON addresses.addressable_type = 'Entity'
       AND addresses.addressable_id = entities.id
       AND addresses.tipo = 'matriz'
      WHERE entities.role_kind IN ('customs_agent', 'consolidator')
        AND addresses.email IS NOT NULL
        AND TRIM(addresses.email) <> ''
      ON CONFLICT (entity_id, email) DO NOTHING
    SQL
  end
end
