namespace :facturador do
  desc "Reconcile invoice statuses with Facturador PAC"
  task :reconcile_invoices, [ :limit, :mode ] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || Facturador::ReconcileInvoicesService::DEFAULT_LIMIT
    mode = args[:mode].to_s.presence || "enqueue"

    if mode == "sync"
      reconciled = Facturador::ReconcileInvoicesService.call(limit: limit)
      puts "Facturador reconciliation processed: #{reconciled.size} invoice(s)"
    else
      Facturador::ReconcileInvoicesJob.perform_later(limit)
      puts "Facturador reconciliation enqueued with limit=#{limit}"
    end
  end
end
