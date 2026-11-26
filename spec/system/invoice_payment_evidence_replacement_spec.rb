require "rails_helper"

RSpec.describe "Reemplazo de comprobante de pago", type: :system do
  it "replaces the receipt only after confirmation" do
    driven_by(:selenium_chrome_headless, screen_size: [ 800, 1000 ])
    admin = create(:user, :admin)
    evidence = create(:invoice_payment_evidence)
    old_blob_id = evidence.receipt_file.blob.id

    login_as(admin, scope: :user)
    visit admin_invoice_payment_evidence_path(evidence)

    Tempfile.create([ "nuevo-comprobante", ".txt" ]) do |file|
      file.write("nuevo comprobante")
      file.flush
      attach_file "Reemplazar comprobante", file.path

      message = dismiss_confirm { click_button "Reemplazar comprobante" }
      expect(message).to include("reemplazar el comprobante", "no se conservará una versión anterior", "pagos y las facturas")
      expect(evidence.reload.receipt_file.blob.id).to eq(old_blob_id)
      expect(evidence.receipt_file.download).to eq("fake receipt content")

      accept_confirm { click_button "Reemplazar comprobante" }
      expect(page).to have_text("Comprobante de pago actualizado correctamente.")
      expect(evidence.reload.receipt_file.download).to eq("nuevo comprobante")
    end
  end
end
