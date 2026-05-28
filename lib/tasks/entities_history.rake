namespace :entities do
  desc "Backfill baseline history events for entities without history"
  task backfill_history_baseline: :environment do
    total = 0

    Entity.find_each do |entity|
      next if entity.entity_events.exists?

      Entities::EventLogger.log_baseline(entity: entity)
      total += 1
    end

    puts "Entity baseline events created: #{total}"
  end
end
