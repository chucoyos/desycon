require "rails_helper"

RSpec.describe "Entities", type: :system do
  let(:user) { create(:user, :admin) }
  let(:entity) { create(:entity) }

  before do
    driven_by(:selenium_chrome_headless, screen_size: [ 1400, 1400 ])

    # Sign in using Warden helpers to keep the session active across requests
    login_as(user, scope: :user)

    visit entity_path(entity)
    entity.reload # Ensure associations are loaded
  end

  describe "entity name update" do
    it "updates the entity name via the edit page" do
      # Go to edit page
      visit edit_entity_path(entity)

      # Fill and submit name form
      fill_in "entity_name", with: "Updated Entity Name"
      click_button "Actualizar Entidad"

      # Verify flash message appears
      expect(page).to have_text("Entidad actualizada exitosamente")
      expect(page).to have_text("Updated Entity Name")
    end
  end

  describe "address creation" do
    it "creates a new address via the edit page" do
      # Go to edit page
      visit edit_entity_path(entity)

      # Click new address button (Turbo frame toggle)
      find("#add-address-btn").click

      # Fill and submit address form
      within "#new_address" do
        select "Matriz", from: "address_tipo"
        fill_in "address_calle", with: "Nueva Calle"
        fill_in "address_numero_exterior", with: "123"
        fill_in "address_colonia", with: "Nueva Colonia"
        fill_in "address_codigo_postal", with: "12345"
        fill_in "address_municipio", with: "Nuevo Municipio"
        fill_in "address_estado", with: "Nuevo Estado"
        fill_in "address_email", with: "test@example.com"
        find("option[value='MX']").select_option
        click_button "Guardar Dirección"
      end

      # Verify success message
      expect(page).to have_text("Dirección agregada exitosamente")
      expect(page).to have_text("Nueva Calle")
    end
  end

  describe "address editing" do
    let!(:address) { create(:address, addressable: entity) }

    before do
      visit edit_entity_path(entity)
    end

    it "displays existing addresses" do
      expect(page).to have_text(address.calle)
    end
  end

  describe "patent update" do
    before do
      entity.update(is_customs_broker: true)
      visit edit_entity_path(entity)
    end

    it "updates the patent number" do
      check "Agente Aduanal"
      fill_in "entity_patent_number", with: "123456789"
      click_button "Actualizar Entidad"

      expect(page).to have_text("Entidad actualizada exitosamente")
      expect(page).to have_text("123456789")
    end
  end

  describe "fiscal profile editing" do
    let!(:fiscal_profile) { create(:fiscal_profile, profileable: entity) }

    it "updates the fiscal profile via the edit page" do
      visit edit_entity_path(entity)

      # Ensure the page is fully loaded
      expect(page).to have_content("Editar Entidad")

      # Ensure the fiscal profile exists and is loaded
      expect(entity.reload.fiscal_profile).to be_present
      expect(page).to have_field("entity_fiscal_profile_attributes_razon_social")

      # Fiscal profile section is now expanded by default
      # Fiscal profile fields are in the main form
      fill_in "entity_fiscal_profile_attributes_razon_social", with: "Nueva Razón Social"
      click_button "Actualizar Entidad"

      expect(page).to have_text("Entidad actualizada exitosamente")

      # Verify the change persisted
      visit entity_path(entity)
      expect(page).to have_text("Nueva Razón Social")
    end
  end
end
