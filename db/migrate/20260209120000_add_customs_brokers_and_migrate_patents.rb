class AddCustomsBrokersAndMigratePatents < ActiveRecord::Migration[8.1]
  class LegacyCustomsAgentPatent < ActiveRecord::Base
    self.table_name = "customs_agent_patents"
  end

  class LegacyEntity < ActiveRecord::Base
    self.table_name = "entities"
  end

  class LegacyAgencyBroker < ActiveRecord::Base
    self.table_name = "agency_brokers"
  end

  class LegacyBlHouseLine < ActiveRecord::Base
    self.table_name = "bl_house_lines"
  end

  def up
    add_column :entities, :is_customs_broker, :boolean, default: false, null: false
    add_column :entities, :patent_number, :string
    add_index :entities, :patent_number, unique: true

    create_table :agency_brokers do |t|
      t.references :agency, null: false, foreign_key: { to_table: :entities }
      t.references :broker, null: false, foreign_key: { to_table: :entities }
      t.timestamps
    end
    add_index :agency_brokers, [ :agency_id, :broker_id ], unique: true

    add_reference :bl_house_lines, :customs_broker, foreign_key: { to_table: :entities }

    migrate_patents_to_brokers

    remove_reference :bl_house_lines, :customs_agent_patent, foreign_key: true
    drop_table :customs_agent_patents
  end

  def down
    create_table :customs_agent_patents do |t|
      t.references :entity, null: false, foreign_key: true
      t.string :patent_number, null: false
      t.timestamps
    end
    add_index :customs_agent_patents, [ :entity_id, :patent_number ], unique: true, name: "index_patents_on_entity_and_number"

    add_reference :bl_house_lines, :customs_agent_patent, foreign_key: true
    remove_reference :bl_house_lines, :customs_broker, foreign_key: { to_table: :entities }

    drop_table :agency_brokers
    remove_index :entities, :patent_number
    remove_column :entities, :patent_number
    remove_column :entities, :is_customs_broker
  end

  private

  def migrate_patents_to_brokers
    return unless table_exists?(:customs_agent_patents)

    duplicates = LegacyCustomsAgentPatent.group(:patent_number).having("COUNT(*) > 1").pluck(:patent_number)
    if duplicates.any?
      duplicates.each do |patent_number|
        ids = LegacyCustomsAgentPatent.where(patent_number: patent_number).order(:id).pluck(:id)
        next if ids.size < 2

        keep_id = ids.first
        duplicate_ids = ids.drop(1)

        # Repoint any BLs to the kept patent before deleting duplicates.
        LegacyBlHouseLine.where(customs_agent_patent_id: duplicate_ids)
          .update_all(customs_agent_patent_id: keep_id)

        # Keep the earliest record and remove the rest (dev/staging cleanup).
        LegacyCustomsAgentPatent.where(id: duplicate_ids).delete_all
      end
    end

    broker_by_patent_id = {}

    LegacyCustomsAgentPatent.find_each do |patent|
      agency = LegacyEntity.find_by(id: patent.entity_id)
      next unless agency

      broker = LegacyEntity.create!(
        name: "Broker #{patent.patent_number} (#{agency.name})",
        is_customs_broker: true,
        patent_number: patent.patent_number
      )

      LegacyAgencyBroker.create!(agency_id: agency.id, broker_id: broker.id)
      broker_by_patent_id[patent.id] = broker.id
    end

    broker_by_patent_id.each do |patent_id, broker_id|
      LegacyBlHouseLine.where(customs_agent_patent_id: patent_id).update_all(customs_broker_id: broker_id)
    end
  end
end
