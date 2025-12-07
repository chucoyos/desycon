require "rails_helper"

RSpec.describe "Entities", type: :system do
  let(:entity) { create(:entity, :with_addresses, :with_patents) }

  before do
    visit entity_path(entity)
  end

  describe "entity name update" do
    it "preserves address and patent buttons" do
      # Count initial buttons
      initial_address_buttons = page.all("button[data-modal-id='address-modal']").count
      initial_patent_buttons = page.all("button[data-modal-id='patent-modal']").count

      # Click name edit button
      find("button[data-modal-id='name-modal']").click

      # Fill and submit name form
      within "#name-modal" do
        fill_in "entity_name", with: "Updated Entity Name"
        click_button "Guardar"
      end

      # Verify buttons are still present with same counts
      expect(page).to have_selector("button[data-modal-id='address-modal']", count: initial_address_buttons)
      expect(page).to have_selector("button[data-modal-id='patent-modal']", count: initial_patent_buttons)

      # Verify flash message appears
      expect(page).to have_text("Entidad actualizada exitosamente")
    end
  end

  describe "address creation" do
    it "preserves existing buttons" do
      # Count initial buttons
      initial_address_buttons = page.all("button[data-modal-id='address-modal']").count
      initial_patent_buttons = page.all("button[data-modal-id='patent-modal']").count

      # Click new address button
      find("button[data-modal-id='new-address-modal']").click

      # Fill and submit address form
      within "#new-address-modal" do
        select "Domicilio Fiscal", from: "address_tipo"
        fill_in "address_calle", with: "Nueva Calle"
        fill_in "address_numero_exterior", with: "123"
        fill_in "address_colonia", with: "Nueva Colonia"
        fill_in "address_codigo_postal", with: "12345"
        fill_in "address_municipio", with: "Nuevo Municipio"
        fill_in "address_estado", with: "Nuevo Estado"
        fill_in "address_email", with: "test@example.com"
        click_button "Agregar Dirección"
      end

      # Verify buttons are still present (address count should increase by 1)
      expect(page).to have_selector("button[data-modal-id='address-modal']", count: initial_address_buttons + 1)
      expect(page).to have_selector("button[data-modal-id='patent-modal']", count: initial_patent_buttons)
    end
  end

  describe "address editing" do
    it "preserves other buttons" do
      skip "No addresses to edit" if entity.addresses.empty?

      # Count initial buttons
      initial_address_buttons = page.all("button[data-modal-id='address-modal']").count
      initial_patent_buttons = page.all("button[data-modal-id='patent-modal']").count

      # Click edit button on first address
      first("button[data-modal-id='address-modal']").click

      # Edit address
      within "#address-modal" do
        fill_in "address_calle", with: "Calle Editada"
        click_button "Guardar Cambios"
      end

      # Verify all buttons are still present with same counts
      expect(page).to have_selector("button[data-modal-id='address-modal']", count: initial_address_buttons)
      expect(page).to have_selector("button[data-modal-id='patent-modal']", count: initial_patent_buttons)

      # Verify flash message appears
      expect(page).to have_text("Dirección actualizada exitosamente")
    end
  end

  describe "patent creation" do
    it "preserves existing buttons" do
      skip "Not a customs agent" unless entity.is_customs_agent?

      # Count initial buttons
      initial_address_buttons = page.all("button[data-modal-id='address-modal']").count
      initial_patent_buttons = page.all("button[data-modal-id='patent-modal']").count

      # Click new patent button
      find("button[data-modal-id='new-patent-modal']").click

      # Fill and submit patent form
      within "#new-patent-modal" do
        fill_in "customs_agent_patent_patent_number", with: "123456789"
        click_button "Agregar Patente"
      end

      # Verify all buttons are still present (patent count should increase by 1)
      expect(page).to have_selector("button[data-modal-id='address-modal']", count: initial_address_buttons)
      expect(page).to have_selector("button[data-modal-id='patent-modal']", count: initial_patent_buttons + 1)

      # Verify flash message appears
      expect(page).to have_text("Patente agregada exitosamente")
    end
  end

  describe "patent editing" do
    it "preserves other buttons" do
      skip "Not a customs agent or no patents" unless entity.is_customs_agent? && entity.customs_agent_patents.any?

      # Count initial buttons
      initial_address_buttons = page.all("button[data-modal-id='address-modal']").count
      initial_patent_buttons = page.all("button[data-modal-id='patent-modal']").count

      # Click edit button on first patent
      first("button[data-modal-id='patent-modal']").click

      # Edit patent
      within "#patent-modal" do
        fill_in "customs_agent_patent_patent_number", with: "987654321"
        click_button "Guardar"
      end

      # Verify all buttons are still present with same counts
      expect(page).to have_selector("button[data-modal-id='address-modal']", count: initial_address_buttons)
      expect(page).to have_selector("button[data-modal-id='patent-modal']", count: initial_patent_buttons)

      # Verify flash message appears
      expect(page).to have_text("Patente actualizada exitosamente")
    end
  end
end
