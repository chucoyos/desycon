class AddPerformanceIndexesToInvoices < ActiveRecord::Migration[8.1]
  disable_ddl_transaction!

  def up
    # Add index on issued_at for sorting and filtering by invoice issue date
    # Critical for the invoices listing to show income by actual invoice date (not import date)
    add_index :invoices, :issued_at, algorithm: :concurrently, if_not_exists: true

    # Add composite index for common filter combinations
    # Improves performance when filtering by issued_at + status
    add_index :invoices, [ :issued_at, :status ], algorithm: :concurrently, if_not_exists: true

    # Composite index for receiver_entity + issued_at (for client filtering)
    add_index :invoices, [ :receiver_entity_id, :issued_at ], algorithm: :concurrently, if_not_exists: true
  end

  def down
    remove_index :invoices, :issued_at, if_exists: true
    remove_index :invoices, [ :issued_at, :status ], if_exists: true
    remove_index :invoices, [ :receiver_entity_id, :issued_at ], if_exists: true
  end
end
