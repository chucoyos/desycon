require 'rails_helper'

RSpec.describe Facturador::ReconcileInvoicesJob, type: :job do
  describe '#perform' do
    it 'passes nightly mode to reconcile service' do
      expect(Facturador::ReconcileInvoicesService).to receive(:call)
        .with(limit: 500, nightly: true)

      described_class.perform_now(500, true)
    end
  end
end
