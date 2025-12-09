class FixBlHouseLineClientForeignKey < ActiveRecord::Migration[8.1]
  def change
    # First, clean up any invalid client_id references that don't exist in entities
    execute <<-SQL
      UPDATE bl_house_lines#{' '}
      SET client_id = NULL#{' '}
      WHERE client_id IS NOT NULL#{' '}
      AND client_id NOT IN (SELECT id FROM entities)
    SQL

    # Remove the incorrect foreign key constraint pointing to clients table
    remove_foreign_key :bl_house_lines, :clients, column: :client_id, name: "fk_rails_78a1b61152"

    # Add the correct foreign key constraint pointing to entities table
    add_foreign_key :bl_house_lines, :entities, column: :client_id
  end
end
