class MoveOriginPortToContainers < ActiveRecord::Migration[8.1]
  def up
    add_reference :containers, :origin_port, foreign_key: { to_table: :ports }

    execute <<~SQL.squish
      UPDATE containers
      SET origin_port_id = voyages.origin_port_id
      FROM voyages
      WHERE voyages.id = containers.voyage_id
        AND containers.origin_port_id IS NULL
    SQL
  end

  def down
    remove_reference :containers, :origin_port, foreign_key: true
  end
end
