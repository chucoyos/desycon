require 'rails_helper'

RSpec.describe Facturador::ReconcileAndSyncInvoiceJob, type: :job do
  describe '#perform' do
    let(:invoice) { create(:invoice, status: 'issued', sat_uuid: 'UUID-JOB-001') }

    it 'reconciles the invoice and then syncs documents' do
      expect(Facturador::ReconcileInvoicesService).to receive(:call_for_invoice)
        .with(invoice: invoice, actor: nil)
      expect(Facturador::SyncInvoiceDocumentsService).to receive(:call)
        .with(invoice: invoice, actor: nil, force: true)

      described_class.perform_now(invoice_id: invoice.id)
    end
  end
end
