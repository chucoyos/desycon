class AddDestinationPortToContainers < ActiveRecord::Migration[8.1]
  def change
    add_reference :containers, :destination_port, null: true, foreign_key: { to_table: :ports }
  end
end
