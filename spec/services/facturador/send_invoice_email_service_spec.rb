require 'rails_helper'

RSpec.describe Facturador::SendInvoiceEmailService, type: :service do
  describe '.call' do
    let(:issuer_entity) { create(:entity, :customs_agent, :with_address) }
    let(:receiver_entity) { create(:entity, :client, :with_address) }
    let(:invoice) do
      create(
        :invoice,
        status: 'issued',
        sat_uuid: 'UUID-EMAIL-001',
        issuer_entity: issuer_entity,
        receiver_entity: receiver_entity,
        payload_snapshot: {
          'tipoDeComprobante' => 'I',
          'receptor' => {
            'nombre' => receiver_entity.name,
            'rfc' => 'EKU9003173C9'
          }
        },
        provider_response: {
          'serie' => 'A',
          'folio' => '123',
          'fecha' => Time.current.iso8601,
          'total' => 1160.0,
          'idResumenComprobante' => 99,
          'satTipoDeComprobante' => 'I',
          'receptorRfc' => 'EKU9003173C9',
          'receptorNombre' => receiver_entity.name
        }
      )
    end
    let(:actor) { create(:user, :admin) }
    let(:client_double) { instance_double(Facturador::Client) }

    before do
      allow(Facturador::Config).to receive(:enabled?).and_return(true)
      allow(Facturador::Config).to receive(:email_enabled?).and_return(true)
      allow(Facturador::Config).to receive(:email_subject).and_return('Asunto prueba')
      allow(Facturador::Config).to receive(:email_message).and_return('Mensaje prueba')
      allow(Facturador::AccessTokenService).to receive(:fetch!).and_return('token-123')
      allow(Facturador::EmisorService).to receive(:emisor_id!).and_return(208)
      allow(Facturador::Client).to receive(:new).with(access_token: 'token-123').and_return(client_double)
      allow(client_double).to receive(:enviar_correo_cfdi)
    end

    it 'sends email via PAC and stores email events' do
      allow(client_double).to receive(:enviar_correo_cfdi).and_return({ 'esValido' => true, 'mensaje' => 'ok' })

      described_class.call(invoice: invoice, actor: actor, trigger: 'manual')

      event_types = invoice.reload.invoice_events.order(:created_at).pluck(:event_type)
      expect(event_types).to include('email_requested', 'email_sent')
      sent_event = invoice.invoice_events.order(:created_at).last
      expect(sent_event.provider_error_message).to include('ok')
    end

    it 'accepts literal true response from PAC as success' do
      allow(client_double).to receive(:enviar_correo_cfdi).and_return(true)

      described_class.call(invoice: invoice, actor: actor, trigger: 'manual')

      event_types = invoice.reload.invoice_events.order(:created_at).pluck(:event_type)
      expect(event_types).to include('email_requested', 'email_sent')
      sent_event = invoice.invoice_events.order(:created_at).last
      expect(sent_event.provider_error_message).to eq('Envio de correo PAC aceptado')
    end

    it 'raises and creates email_failed when PAC rejects email send' do
      allow(client_double).to receive(:enviar_correo_cfdi).and_return({
        'esValido' => false,
        'errores' => [ { 'mensaje' => 'Correo inválido' } ]
      })

      expect {
        described_class.call(invoice: invoice, actor: actor, trigger: 'manual')
      }.to raise_error(Facturador::RequestError, /Correo inválido/)

      expect(invoice.reload.invoice_events.order(:created_at).last.event_type).to eq('email_failed')
    end

    it 'raises when receiver fiscal email is missing' do
      receiver_entity.fiscal_address.destroy!

      expect {
        described_class.call(invoice: invoice, actor: actor, trigger: 'manual')
      }.to raise_error(Facturador::ValidationError, /Receiver fiscal email is missing/)
    end

    it 'raises when email feature is disabled on manual trigger' do
      allow(Facturador::Config).to receive(:email_enabled?).and_return(false)

      expect {
        described_class.call(invoice: invoice, actor: actor, trigger: 'manual')
      }.to raise_error(Facturador::ValidationError, /Email sending via PAC is disabled/)

      expect(invoice.reload.invoice_events.where(event_type: 'email_requested')).to be_empty
      expect(client_double).not_to have_received(:enviar_correo_cfdi)
    end

    it 'returns invoice unchanged when email feature is disabled on auto trigger' do
      allow(Facturador::Config).to receive(:email_enabled?).and_return(false)

      result = described_class.call(invoice: invoice, actor: actor, trigger: 'auto_issue')

      expect(result).to eq(invoice)
      expect(invoice.reload.invoice_events.where(event_type: 'email_requested')).to be_empty
      expect(client_double).not_to have_received(:enviar_correo_cfdi)
    end

    it 'treats esValido="false" as invalid response' do
      allow(client_double).to receive(:enviar_correo_cfdi).and_return({
        'esValido' => 'false',
        'mensaje' => 'No se pudo enviar'
      })

      expect {
        described_class.call(invoice: invoice, actor: actor, trigger: 'manual')
      }.to raise_error(Facturador::RequestError, /No se pudo enviar/)
    end

    it 'refreshes provider summary before send when idResumenComprobante is missing' do
      invoice.update!(
        provider_response: {
          'serie' => 'A',
          'folio' => nil,
          'fecha' => Time.current.iso8601,
          'total' => 1160.0,
          'idResumenComprobante' => nil,
          'satTipoDeComprobante' => 'I',
          'receptorRfc' => 'EKU9003173C9',
          'receptorNombre' => receiver_entity.name
        }
      )

      allow(client_double).to receive(:buscar_comprobantes).and_return(
        {
          'resumenComprobante' => [
            {
              'uuid' => invoice.sat_uuid,
              'idResumenComprobante' => 5245,
              'folio' => '1830',
              'serie' => 'A',
              'fecha' => Time.current.iso8601,
              'total' => 1160.0,
              'receptorRfc' => 'EKU9003173C9',
              'receptorNombre' => receiver_entity.name,
              'satTipoDeComprobante' => 'I'
            }
          ]
        }
      )
      allow(client_double).to receive(:enviar_correo_cfdi).and_return(true)

      described_class.call(invoice: invoice, actor: actor, trigger: 'auto_issue')

      expect(client_double).to have_received(:buscar_comprobantes)
      expect(client_double).to have_received(:enviar_correo_cfdi).with(
        emisor_id: 208,
        payload: hash_including(
          'cfdi' => hash_including('idResumenComprobante' => 5245, 'folio' => '1830')
        )
      )
    end

    it 'sends email only to receiver and does not require issuer fiscal email' do
      issuer_entity.fiscal_address.destroy!
      allow(client_double).to receive(:enviar_correo_cfdi).and_return({ 'esValido' => true, 'mensaje' => 'ok' })

      described_class.call(invoice: invoice, actor: actor, trigger: 'manual')

      expect(client_double).to have_received(:enviar_correo_cfdi).with(
        emisor_id: 208,
        payload: hash_including(
          'para' => receiver_entity.fiscal_address.email,
          'cc' => receiver_entity.fiscal_address.email,
          'responderA' => receiver_entity.fiscal_address.email
        )
      )

      sent_payload = nil
      expect(client_double).to have_received(:enviar_correo_cfdi) do |args|
        sent_payload = args[:payload]
      end
      expect(sent_payload['cc']).to eq(receiver_entity.fiscal_address.email)
    end
  end
end
