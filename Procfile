web: bundle exec puma -C config/puma.rb
worker: bundle exec bin/jobs --config-file=config/queue.default.yml
worker_active_storage: SOLID_QUEUE_SKIP_RECURRING=true bundle exec bin/jobs --config-file=config/queue.active_storage.yml
