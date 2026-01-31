class RemoveOriginPortFromVoyages < ActiveRecord::Migration[8.1]
  def up
    remove_reference :voyages, :origin_port, foreign_key: { to_table: :ports }
  end

  def down
    add_reference :voyages, :origin_port, foreign_key: { to_table: :ports }
  end
end
