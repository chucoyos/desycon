class CreatePhotoDownloadLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :photo_download_links do |t|
      t.references :attachable, polymorphic: true, null: false
      t.string :section, null: false
      t.references :created_by, null: false, foreign_key: { to_table: :users }
      t.references :revoked_by, foreign_key: { to_table: :users }
      t.datetime :expires_at, null: false
      t.datetime :revoked_at
      t.datetime :last_accessed_at

      t.timestamps
    end

    add_index :photo_download_links, :expires_at
    add_index :photo_download_links, :revoked_at
    add_index :photo_download_links, [ :attachable_type, :attachable_id, :section ], name: "index_photo_download_links_on_attachable_and_section"
  end
end
