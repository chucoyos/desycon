namespace :facturador do
  desc "Reconcile invoice statuses with Facturador PAC"
  task :reconcile_invoices, [ :limit ] => :environment do |_task, args|
    limit = args[:limit].presence&.to_i || Facturador::ReconcileInvoicesService::DEFAULT_LIMIT
    reconciled = Facturador::ReconcileInvoicesService.call(limit: limit)
    puts "Facturador reconciliation processed: #{reconciled.size} invoice(s)"
  end
end
