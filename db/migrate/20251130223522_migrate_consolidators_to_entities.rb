class MigrateConsolidatorsToEntities < ActiveRecord::Migration[8.1]
  def up
    # Renombrar tabla consolidators actual para preservar datos
    rename_table :consolidators, :consolidators_old

    # Crear nueva tabla consolidators (perfiles)
    create_table :consolidators do |t|
      t.references :entity, null: false, foreign_key: true
      t.timestamps
    end
    add_index :consolidators, :entity_id, unique: true unless index_exists?(:consolidators, :entity_id)

    # Migrar datos: crear entities desde consolidators_old
    execute <<-SQL
      INSERT INTO entities (name, is_consolidator, created_at, updated_at)
      SELECT name, true, created_at, updated_at
      FROM consolidators_old
    SQL

    # Crear perfiles de consolidador para cada entity
    execute <<-SQL
      INSERT INTO consolidators (entity_id, created_at, updated_at)
      SELECT e.id, e.created_at, e.updated_at
      FROM entities e
      WHERE e.is_consolidator = true
    SQL

    # Actualizar containers para usar entity_id
    execute <<-SQL
      UPDATE containers c
      SET consolidator_entity_id = (
        SELECT e.id#{' '}
        FROM entities e
        INNER JOIN consolidators con ON con.entity_id = e.id
        INNER JOIN consolidators_old old ON old.name = e.name
        WHERE old.id = c.consolidator_id
      )
    SQL
  end

  def down
    # Restaurar tabla original
    drop_table :consolidators
    rename_table :consolidators_old, :consolidators

    # Limpiar referencias
    remove_column :containers, :consolidator_entity_id

    # Eliminar entities creadas
    execute "DELETE FROM entities WHERE is_consolidator = true"
  end
end
