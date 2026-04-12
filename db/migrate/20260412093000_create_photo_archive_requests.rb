class CreatePhotoArchiveRequests < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_archive_requests do |t|
      t.references :attachable, polymorphic: true, null: false
      t.references :requested_by, null: false, foreign_key: { to_table: :users }
      t.string :section, null: false
      t.string :status, null: false, default: "pending"
      t.integer :photos_count
      t.text :error_message
      t.datetime :generated_at
      t.datetime :expires_at

      t.timestamps
    end

    add_index :photo_archive_requests, [ :attachable_type, :attachable_id, :section, :requested_by_id ], name: "idx_photo_archive_requests_lookup"
    add_index :photo_archive_requests, :status
  end
end
