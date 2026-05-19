namespace :facturador do
  desc "Reconcile invoice statuses with Facturador PAC"
  task :reconcile_invoices, [ :limit, :mode, :nightly ] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || Facturador::ReconcileInvoicesService::DEFAULT_LIMIT
    mode = args[:mode].to_s.presence || "enqueue"
    nightly = ActiveModel::Type::Boolean.new.cast(args[:nightly])

    if mode == "sync"
      reconciled = Facturador::ReconcileInvoicesService.call(limit: limit, nightly: nightly)
      puts "Facturador reconciliation processed: #{reconciled.size} invoice(s)"
    else
      Facturador::ReconcileInvoicesJob.perform_later(limit, nightly)
      puts "Facturador reconciliation enqueued with limit=#{limit} nightly=#{nightly}"
    end
  end

  desc "Import external invoices from Facturador"
  task :import_external_invoices, [ :days, :mode, :dry_run, :max_pages, :take ] => :environment do |_task, args|
    unless Facturador::Config.external_invoices_runtime_enabled?
      puts "Facturador external import skipped: runtime gate disabled for environment=#{Rails.env}"
      next
    end

    days = args[:days].presence&.to_i
    days = Facturador::Config.external_sync_initial_backfill_days if days.to_i <= 0

    mode = args[:mode].to_s.presence || "enqueue"
    dry_run = ActiveModel::Type::Boolean.new.cast(args[:dry_run])
    max_pages = args[:max_pages].presence&.to_i
    take = args[:take].presence&.to_i

    window_start = days.days.ago
    window_end = Time.current

    if mode == "sync"
      summary = Facturador::ImportExternalInvoicesService.call(
        window_start: window_start,
        window_end: window_end,
        dry_run: dry_run,
        max_pages: max_pages,
        take: take,
        source: "rake_sync"
      )

      puts "Facturador external import processed: read=#{summary.read_count} created=#{summary.created_count} updated=#{summary.updated_count} duplicates=#{summary.duplicate_count} pending=#{summary.pending_assignment_count} errors=#{summary.error_count}"
    else
      Facturador::ImportExternalInvoicesJob.perform_later(
        window_start_iso8601: window_start.iso8601,
        window_end_iso8601: window_end.iso8601,
        dry_run: dry_run,
        max_pages: max_pages,
        take: take,
        source: "rake_enqueue"
      )

      puts "Facturador external import enqueued with days=#{days} dry_run=#{dry_run} max_pages=#{max_pages || 'auto'} take=#{take || Facturador::Config.external_sync_take}"
    end
  end
end
