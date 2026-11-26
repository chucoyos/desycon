require "rails_helper"
require "ostruct"
require "roo"

RSpec.describe "Admin::InvoicePaymentEvidences", type: :request do
  let(:admin_user) { create(:user, :admin) }
  let(:executive_user) { create(:user, :executive) }
  let(:customs_user) { create(:user, :customs_broker) }
  let(:customs_agent) { customs_user.entity }
  let(:client_entity) { create(:entity, :client, customs_agent: customs_agent) }
  let(:invoice) { create(:invoice, status: "issued", receiver_entity: client_entity) }
  let!(:evidence) do
    create(
      :invoice_payment_evidence,
      invoice: invoice,
      customs_agent: customs_agent,
      submitted_by: customs_user,
      status: "pending"
    )
  end

  describe "GET /admin/invoice_payment_evidences" do
    it "allows admin users" do
      sign_in admin_user, scope: :user

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Evidencias de pago")
      expect(response.body).to include("Envío")
      expect(response.body).to include(I18n.l(evidence.created_at, format: "%d/%m/%Y %H:%M"))
    end

    it "allows executive users" do
      sign_in executive_user, scope: :user

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:success)
    end

    it "rejects customs users" do
      sign_in customs_user, scope: :user

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:redirect)
      expect(flash[:alert]).to be_present
    end

    it "limits evidences to payment dates from the last week by default" do
      sign_in admin_user, scope: :user

      recent_payment = create(:invoice_payment, invoice: invoice, paid_at: 5.days.ago, amount: 500)
      recent_evidence = create(
        :invoice_payment_evidence,
        invoice: invoice,
        invoice_payment: recent_payment,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        status: "linked",
        reference: "REF-RECENT-ONE-MONTH",
        created_at: 5.days.ago
      )
      old_payment = create(:invoice_payment, invoice: invoice, paid_at: 2.months.ago, amount: 500)
      create(
        :invoice_payment_evidence,
        invoice: invoice,
        invoice_payment: old_payment,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        status: "linked",
        reference: "REF-OLD-OUTSIDE-MONTH",
        created_at: 2.months.ago
      )

      get admin_invoice_payment_evidences_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include(recent_evidence.reference)
      expect(response.body).not_to include("REF-OLD-OUTSIDE-MONTH")
    end

    it "filters evidences by the selected payment date range" do
      sign_in admin_user, scope: :user

      target_date = 2.months.ago.to_date
      in_range_payment = create(:invoice_payment, invoice: invoice, paid_at: target_date.noon, amount: 500)
      create(
        :invoice_payment_evidence,
        invoice: invoice,
        invoice_payment: in_range_payment,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        status: "linked",
        reference: "REF-IN-RANGE",
        created_at: target_date.noon
      )
      out_range_payment = create(:invoice_payment, invoice: invoice, paid_at: 5.days.ago, amount: 500)
      create(
        :invoice_payment_evidence,
        invoice: invoice,
        invoice_payment: out_range_payment,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        status: "linked",
        reference: "REF-OUT-RANGE",
        created_at: 5.days.ago
      )

      get admin_invoice_payment_evidences_path, params: {
        start_date: (target_date - 1.day).iso8601,
        end_date: (target_date + 1.day).iso8601
      }

      expect(response).to have_http_status(:success)
      expect(response.body).to include("REF-IN-RANGE")
      expect(response.body).not_to include("REF-OUT-RANGE")
    end

    it "exports payment application report in xlsx format" do
      sign_in admin_user, scope: :user

      issued_invoice = create(
        :invoice,
        status: "issued",
        receiver_entity: client_entity,
        provider_response: { "serie" => "A", "folio" => "123" }
      )
      payment = create(
        :invoice_payment,
        invoice: issued_invoice,
        paid_at: Date.new(2026, 4, 9),
        amount: 789.45,
        tracking_key: "00012345678901234567"
      )

      create(
        :invoice_payment_evidence,
        invoice: issued_invoice,
        invoice_payment: payment,
        customs_agent: customs_agent,
        submitted_by: customs_user,
        status: "linked",
        reference: "REF-EXCEL-001",
        created_at: 2.days.ago
      )

      get admin_invoice_payment_evidences_path(format: :xlsx), params: {
        start_date: "2026-04-09",
        end_date: "2026-04-09",
        date_filter_type: "paid_at"
      }

      expect(response).to have_http_status(:ok)
      expect(response.content_type).to include("application/vnd.openxmlformats-officedocument.spreadsheetml.sheet")

      tempfile = Tempfile.new([ "aplicacion_pagos", ".xlsx" ])
      tempfile.binmode
      tempfile.write(response.body)
      tempfile.rewind

      workbook = Roo::Excelx.new(tempfile.path)
      sheet = workbook.sheet(0)

      expect(sheet.row(1)).to eq([
        "Factura",
        "Fecha de Pago",
        "Monto",
        "Clave Rastreo",
        "Agencia Aduanal",
        "Receptor"
      ])

      row = sheet.row(2)
      expect(row[0]).to eq("A 123")
      expect(row[1]).to be_present
      expect(row[2]).to eq(789.45)
      expect(row[3]).to eq("00012345678901234567")
      expect(row[4]).to eq(customs_agent.name)
      expect(row[5]).to eq(client_entity.name)

      tempfile.close!
    end
  end

  describe "GET /admin/invoice_payment_evidences/:id" do
    it "renders linked invoice navigation to invoice show without selection link" do
      sign_in admin_user, scope: :user

      get admin_invoice_payment_evidence_path(evidence)

      expect(response).to have_http_status(:success)
      expect(response.body).to include(invoice_path(invoice))
      expect(response.body).to include(I18n.l(evidence.created_at, format: "%d/%m/%Y %H:%M"))
      expect(response.body).not_to include("Seleccionar")
      expect(response.body).to include("Reemplazar comprobante")
      expect(response.body).to include('name="invoice_payment_evidence[receipt_file]"')
      expect(Nokogiri::HTML(response.body).at_css('label[for="invoice_payment_evidence_receipt_file"]').text).to eq("Reemplazar comprobante")
      expect(response.body).to include("Advertencia:")
    end
  end

  describe "PATCH /admin/invoice_payment_evidences/:id/replace_receipt" do
    let(:new_file) do
      Rack::Test::UploadedFile.new(StringIO.new("nuevo comprobante"), "application/pdf", original_filename: "nuevo.pdf")
    end
    let(:path) { replace_receipt_admin_invoice_payment_evidence_path(evidence, invoice_id: invoice.id) }

    %w[pending linked rejected].each do |status|
      it "allows an administrator to replace a #{status} evidence without changing its other data" do
        evidence.update!(status: status, review_comment: "Revisión conservada")
        previous_attributes = evidence.attributes.except("updated_at")
        previous_blob_id = evidence.receipt_file.blob.id
        sign_in admin_user, scope: :user

        patch path, params: { invoice_payment_evidence: { receipt_file: new_file, status: "pending" } }

        expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence, invoice_id: invoice.id))
        expect(flash[:notice]).to be_present
        evidence.reload
        expect(evidence.attributes.except("updated_at")).to eq(previous_attributes)
        expect(evidence.receipt_file.blob.id).not_to eq(previous_blob_id)
        expect(evidence.receipt_file.download).to eq("nuevo comprobante")
      end
    end

    it "allows an executive to replace the receipt without imposing a new file type restriction" do
      sign_in executive_user, scope: :user
      text_file = Rack::Test::UploadedFile.new(StringIO.new("otro formato"), "text/plain", original_filename: "nuevo.txt")

      patch path, params: { invoice_payment_evidence: { receipt_file: text_file } }

      expect(flash[:notice]).to be_present
      expect(evidence.reload.receipt_file.download).to eq("otro formato")
    end

    [ :customs_broker, :consolidator, :tramitador ].each do |role|
      it "denies replacement by a #{role}" do
        old_blob_id = evidence.receipt_file.blob.id
        sign_in(role == :customs_broker ? customs_user : create(:user, role), scope: :user)

        patch path, params: { invoice_payment_evidence: { receipt_file: new_file } }

        expect(response).to have_http_status(:redirect)
        expect(flash[:alert]).to be_present
        expect(evidence.reload.receipt_file.blob.id).to eq(old_blob_id)
      end
    end

    [ nil, "invalid", { unexpected: "value" } ].each do |file|
      it "rejects a missing or invalid file (#{file.inspect}) without changing the receipt" do
        old_blob_id = evidence.receipt_file.blob.id
        sign_in admin_user, scope: :user

        patch path, params: { invoice_payment_evidence: { receipt_file: file } }

        expect(flash[:alert]).to be_present
        expect(evidence.reload.receipt_file.blob.id).to eq(old_blob_id)
        expect(evidence.receipt_file.download).to eq("fake receipt content")
      end
    end

    it "leaves the existing receipt intact when the upload fails" do
      old_blob_id = evidence.receipt_file.blob.id
      sign_in admin_user, scope: :user
      allow(ActiveStorage::Blob.service).to receive(:upload).and_raise(IOError, "falló la carga")

      expect {
        patch path, params: { invoice_payment_evidence: { receipt_file: new_file } }
      }.to raise_error(IOError, "falló la carga")

      expect(evidence.reload.receipt_file.blob.id).to eq(old_blob_id)
      expect(evidence.receipt_file.download).to eq("fake receipt content")
    end

    it "keeps the existing receipt and reports an error when the evidence is invalid" do
      evidence.update_column(:reference, "")
      old_blob_id = evidence.receipt_file.blob.id
      sign_in admin_user, scope: :user

      patch path, params: { invoice_payment_evidence: { receipt_file: new_file } }

      expect(flash[:alert]).to include("No fue posible actualizar el comprobante")
      expect(evidence.reload.receipt_file.blob.id).to eq(old_blob_id)
      expect(evidence.receipt_file.download).to eq("fake receipt content")
    end

    it "preserves linked invoices, payment and its separate receipt" do
      other_invoice = create(:invoice, status: "issued", receiver_entity: client_entity)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: invoice)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: other_invoice)
      payment = create(:invoice_payment, invoice: invoice)
      payment.receipt_file.attach(io: StringIO.new("comprobante de pago"), filename: "pago.pdf", content_type: "application/pdf")
      evidence.update!(invoice_payment: payment, status: "linked")
      payment_blob_id = payment.receipt_file.blob.id
      sign_in admin_user, scope: :user

      patch path, params: { invoice_payment_evidence: { receipt_file: new_file } }

      expect(evidence.reload.invoices.pluck(:id)).to match_array([ invoice.id, other_invoice.id ])
      expect(evidence.invoice_payment_id).to eq(payment.id)
      expect(payment.reload.receipt_file.blob.id).to eq(payment_blob_id)
      expect(payment.receipt_file.download).to eq("comprobante de pago")
      get invoice_invoice_payment_path(invoice, payment)
      expect(response.body).to include(rails_blob_path(evidence.receipt_file, disposition: "inline"))
      expect(response.body).to include(rails_blob_path(payment.receipt_file, disposition: "inline"))
    end
  end

  describe "GET /admin/invoice_payment_evidences/:id with multiple PUE invoices" do
    it "renders enabled grouped amount inputs prefilled with each outstanding balance" do
      sign_in admin_user, scope: :user

      pue_one = create(:invoice, status: "issued", receiver_entity: client_entity, payload_snapshot: { metodoPago: "PUE" })
      pue_two = create(:invoice, status: "issued", receiver_entity: client_entity, payload_snapshot: { metodoPago: "PUE" })
      multi_evidence = create(:invoice_payment_evidence, invoice: pue_one, customs_agent: customs_agent, submitted_by: customs_user)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: multi_evidence, invoice: pue_one)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: multi_evidence, invoice: pue_two)

      get admin_invoice_payment_evidence_path(multi_evidence)

      expect(response).to have_http_status(:success)
      expect(response.body).to include("register_payment[invoice_amounts][#{pue_one.id}]")
      expect(response.body).to include("register_payment[invoice_amounts][#{pue_two.id}]")
      expect(response.body).to include(%(value="#{pue_one.outstanding_amount.to_s('F')}"))
      expect(response.body).not_to match(/<input[^>]*value="Registrar y vincular pago"[^>]*\sdisabled(="disabled")?[\s>]/)
    end
  end

  describe "PATCH /admin/invoice_payment_evidences/:id/reject" do
    it "rejects evidence with mandatory comment" do
      sign_in admin_user, scope: :user

      expect do
        patch reject_admin_invoice_payment_evidence_path(evidence), params: {
          review_comment: "Comprobante ilegible"
        }
      end.to change {
        Notification.where(recipient: customs_user, notifiable: evidence).count
      }.by(1)

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("rejected")
      expect(evidence.review_comment).to eq("Comprobante ilegible")

      rejection_notification = Notification.where(recipient: customs_user, notifiable: evidence).order(:id).last
      expect(rejection_notification.action).to include("rechazo evidencia de pago")
      expect(rejection_notification.action).to include("Motivo: Comprobante ilegible")
    end
  end

  describe "POST /admin/invoice_payment_evidences/:id/register_payment" do
    it "registers a payment and links the evidence" do
      sign_in admin_user, scope: :user

      payment = create(:invoice_payment, invoice: invoice)
      expect(Facturador::RegisterInvoicePaymentService).to receive(:call).with(
        invoice: evidence.invoice,
        amount: "500.00",
        paid_at: Date.current.iso8601,
        payment_method: "03",
        reference: "BLH-20001",
        tracking_key: "TRACK-ADMIN-001",
        notes: "Pago confirmado",
        actor: admin_user
      ).and_return(payment)

      post register_payment_admin_invoice_payment_evidence_path(evidence), params: {
        register_payment: {
          amount: "500.00",
          paid_at: Date.current.iso8601,
          payment_method: "03",
          reference: "BLH-20001",
          tracking_key: "TRACK-ADMIN-001",
          notes: "Pago confirmado",
          review_comment: "Registrado por ejecutivo"
        }
      }

      evidence.reload
      expect(response).to redirect_to(invoice_invoice_payment_path(invoice, payment))
      expect(evidence.status).to eq("linked")
      expect(evidence.invoice_payment_id).to eq(payment.id)
      expect(evidence.review_comment).to include("Registrado por ejecutivo")
    end

    it "registers grouped payments for multi-invoice evidence" do
      sign_in admin_user, scope: :user

      second_invoice = create(:invoice, status: "issued", receiver_entity: client_entity)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: invoice)
      create(:invoice_payment_evidence_link, invoice_payment_evidence: evidence, invoice: second_invoice)

      first_payment = create(:invoice_payment, invoice: invoice)
      grouped_result = OpenStruct.new(payments: [ first_payment ], complement_invoice: nil)

      expect(Facturador::RegisterGroupedInvoicePaymentsService).to receive(:call).with(
        evidence: evidence,
        invoice_amounts: {
          invoice.id.to_s => "500.00",
          second_invoice.id.to_s => "300.00"
        },
        paid_at: Date.current.iso8601,
        payment_method: "03",
        reference: "BLH-GROUP-001",
        tracking_key: "TRACK-GROUP-001",
        notes: "Pago agrupado",
        actor: admin_user
      ).and_return(grouped_result)

      post register_payment_admin_invoice_payment_evidence_path(evidence), params: {
        register_payment: {
          invoice_amounts: {
            invoice.id.to_s => "500.00",
            second_invoice.id.to_s => "300.00"
          },
          paid_at: Date.current.iso8601,
          payment_method: "03",
          reference: "BLH-GROUP-001",
          tracking_key: "TRACK-GROUP-001",
          notes: "Pago agrupado",
          review_comment: "Registrado en bloque"
        }
      }

      evidence.reload
      expect(response).to redirect_to(admin_invoice_payment_evidence_path(evidence))
      expect(evidence.status).to eq("linked")
      expect(evidence.invoice_payment_id).to eq(first_payment.id)
      expect(evidence.review_comment).to include("Registrado en bloque")
      expect(evidence.review_comment).to include("2 facturas")
    end
  end
end
