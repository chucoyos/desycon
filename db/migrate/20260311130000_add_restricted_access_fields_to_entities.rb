class AddRestrictedAccessFieldsToEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :entities, :enforce_overdue_payment_rule, :boolean, null: false, default: true
    add_column :entities, :restricted_access_enabled, :boolean, null: false, default: false
    add_column :entities, :restricted_access_reason, :string
    add_column :entities, :restricted_access_enabled_at, :datetime
    add_column :entities, :restricted_access_unlocked_at, :datetime

    add_index :entities, :enforce_overdue_payment_rule
    add_index :entities, :restricted_access_enabled
    add_index :entities, :restricted_access_enabled_at
  end
end
