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
end
