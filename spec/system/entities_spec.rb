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

      # Avoid client-only fiscal required fields from blocking this scenario
      select "Consolidador", from: "entity_role_kind"

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

        country_input = find("input[name='address_country_search']")
        country_input.fill_in(with: "mex")
        expect(page).to have_css("[data-catalog-autocomplete-target='results'] button", wait: 5)
        country_input.send_keys(:enter)

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
      entity.update(role_kind: "customs_broker")
      visit edit_entity_path(entity)
    end

    it "updates the patent number" do
      select "Agente Aduanal", from: "entity_role_kind"
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

  describe "email recipients management" do
    let(:agency) { create(:entity, :customs_agent) }

    it "persists multiple email recipients from the form" do
      visit edit_entity_path(agency)

      within "#email-recipients-container" do
        all(".email-recipient-row").first.tap do |row|
          row.fill_in "Correo", with: "agencia1@correo.com"
          row.fill_in "Orden", with: "0"
          row.check "Principal"
          row.check "Activo"
        end
      end

      find("#add-email-recipient-btn").click
      find("#add-email-recipient-btn").click

      within "#email-recipients-container" do
        rows = all(".email-recipient-row")

        rows[1].fill_in "Correo", with: "agencia2@correo.com"
        rows[1].fill_in "Orden", with: "1"
        rows[1].uncheck "Principal"
        rows[1].check "Activo"

        rows[2].fill_in "Correo", with: "agencia3@correo.com"
        rows[2].fill_in "Orden", with: "2"
        rows[2].uncheck "Principal"
        rows[2].check "Activo"
      end

      click_button "Actualizar Entidad"

      expect(page).to have_text("Entidad actualizada exitosamente")
      expect(agency.reload.delivery_email_recipients).to eq([ "agencia1@correo.com", "agencia2@correo.com", "agencia3@correo.com" ])
    end

    it "persists multiple email recipients when creating a new customs agency" do
      visit new_entity_path

      fill_in "entity_name", with: "Agencia Nueva"
      select "Agencia Aduanal", from: "entity_role_kind"

      find("#add-email-recipient-btn").click
      find("#add-email-recipient-btn").click

      within "#email-recipients-container" do
        rows = all(".email-recipient-row")
        expect(rows.size).to eq(2)

        rows[0].fill_in "Correo", with: "nueva1@correo.com"
        rows[0].fill_in "Orden", with: "0"
        rows[0].check "Principal"
        rows[0].check "Activo"

        rows[1].fill_in "Correo", with: "nueva2@correo.com"
        rows[1].fill_in "Orden", with: "1"
        rows[1].uncheck "Principal"
        rows[1].check "Activo"
      end

      fill_in "entity_addresses_attributes_0_codigo_postal", with: "64000"
      fill_in "entity_addresses_attributes_0_email", with: "fiscal@agencianueva.com"

      click_button "Crear Entidad"

      expect(page).to have_text("Entidad creada exitosamente")
      created = Entity.find_by!(name: "Agencia Nueva")
      expect(created.role_kind).to eq("customs_agent")
      expect(created.delivery_email_recipients).to eq([ "nueva1@correo.com", "nueva2@correo.com" ])
    end
  end
end
