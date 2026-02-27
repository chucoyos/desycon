class CreatePhotos < ActiveRecord::Migration[8.1]
  def change
    create_table :photos do |t|
      t.references :attachable, polymorphic: true, null: false
      t.string :section, null: false
      t.integer :position, null: false, default: 0
      t.references :uploaded_by, foreign_key: { to_table: :users }

      t.timestamps
    end

    add_index :photos, [ :attachable_type, :attachable_id, :section, :created_at ], name: "index_photos_on_attachable_and_section"
  end
end
