require 'rails_helper'

RSpec.describe "BlHouseLines", type: :request do
  let(:user) { create(:user, :executive) }
  let(:customs_agent) { create(:entity, :customs_agent) }
  let(:client) { create(:entity, :client) }
  let(:container) { create(:container) }
  let(:packaging) { create(:packaging) }

  let(:valid_attributes) {
    {
      blhouse: "BLH001234",
      partida: 1,
      cantidad: 10,
      contiene: "Contenido de prueba",
      marcas: "Marcas de prueba",
      peso: 100.5,
      volumen: 2.5,
      customs_agent_id: customs_agent.id,
      client_id: client.id,
      container_id: container.id,
      packaging_id: packaging.id,
      status: "activo"
    }
  }

  let(:invalid_attributes) {
    {
      blhouse: "",
      partida: nil,
      cantidad: 0,
      customs_agent_id: nil,
      client_id: nil,
      container_id: nil,
      packaging_id: nil
    }
  }

  describe "GET /bl_house_lines" do
    it "renders a successful response" do
      sign_in user, scope: :user
      create(:bl_house_line)
      get bl_house_lines_url
      expect(response).to be_successful
    end
  end

  describe "GET /bl_house_lines/:id" do
    it "renders a successful response" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      get bl_house_line_url(bl_house_line)
      expect(response).to be_successful
    end
  end

  describe "GET /bl_house_lines/new" do
    it "renders a successful response" do
      sign_in user, scope: :user
      get new_bl_house_line_url
      expect(response).to be_successful
    end
  end

  describe "GET /bl_house_lines/:id/edit" do
    it "renders a successful response" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      get edit_bl_house_line_url(bl_house_line)
      expect(response).to be_successful
    end
  end

  describe "POST /bl_house_lines" do
    context "with valid parameters" do
      it "creates a new BlHouseLine" do
        sign_in user, scope: :user
        expect {
          post bl_house_lines_url, params: { bl_house_line: valid_attributes }
        }.to change(BlHouseLine, :count).by(1)
      end

      it "redirects to the created bl_house_line" do
        sign_in user, scope: :user
        post bl_house_lines_url, params: { bl_house_line: valid_attributes }
        expect(response).to redirect_to(bl_house_line_url(BlHouseLine.last))
      end
    end

    context "with invalid parameters" do
      it "does not create a new BlHouseLine" do
        sign_in user, scope: :user
        expect {
          post bl_house_lines_url, params: { bl_house_line: invalid_attributes }
        }.to change(BlHouseLine, :count).by(0)
      end

      it "renders a response with 422 status (i.e. to display the 'new' template)" do
        sign_in user, scope: :user
        post bl_house_lines_url, params: { bl_house_line: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /bl_house_lines/:id" do
    context "with valid parameters" do
      let(:new_attributes) {
        {
          blhouse: "BLH009876",
          cantidad: 20
        }
      }

      it "updates the requested bl_house_line" do
        sign_in user, scope: :user
        bl_house_line = create(:bl_house_line)
        patch bl_house_line_url(bl_house_line), params: { bl_house_line: new_attributes }
        bl_house_line.reload
        expect(bl_house_line.blhouse).to eq("BLH009876")
        expect(bl_house_line.cantidad).to eq(20)
      end

      it "redirects to the bl_house_line" do
        sign_in user, scope: :user
        bl_house_line = create(:bl_house_line)
        patch bl_house_line_url(bl_house_line), params: { bl_house_line: new_attributes }
        bl_house_line.reload
        expect(response).to redirect_to(bl_house_line_url(bl_house_line))
      end
    end

    context "with invalid parameters" do
      it "renders a response with 422 status (i.e. to display the 'edit' template)" do
        sign_in user, scope: :user
        bl_house_line = create(:bl_house_line)
        patch bl_house_line_url(bl_house_line), params: { bl_house_line: invalid_attributes }
        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "DELETE /bl_house_lines/:id" do
    it "destroys the requested bl_house_line" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      expect {
        delete bl_house_line_url(bl_house_line)
      }.to change(BlHouseLine, :count).by(-1)
    end

    it "redirects to the bl_house_lines list" do
      sign_in user, scope: :user
      bl_house_line = create(:bl_house_line)
      delete bl_house_line_url(bl_house_line)
      expect(response).to redirect_to(bl_house_lines_url)
    end
  end

  describe "PATCH /bl_house_lines/:id/perform_reassign" do
    let(:new_agent) { create(:entity, :customs_agent) }
    let(:new_broker) { create(:entity, :customs_broker) }
    let(:new_client) { create(:entity, :client, customs_agent: new_agent) }
    let(:bl_house_line) { create(:bl_house_line, customs_agent: customs_agent) }

    before do
      AgencyBroker.create!(agency: new_agent, broker: new_broker)
      create(:service_catalog,
        name: "Asignacion electronica de carga",
        code: "BL-ASIG",
        applies_to: "bl_house_line")
    end

    it "updates the bl house line and creates a service" do
      sign_in user, scope: :user

      expect {
        patch perform_reassign_bl_house_line_url(bl_house_line), params: {
          reassign: {
            new_customs_agent_id: new_agent.id,
            new_customs_broker_id: new_broker.id,
            new_client_id: new_client.id
          }
        }
      }.to change(BlHouseLineService, :count).by(1)

      bl_house_line.reload
      expect(bl_house_line.customs_agent_id).to eq(new_agent.id)
      expect(bl_house_line.customs_broker_id).to eq(new_broker.id)
      expect(bl_house_line.client_id).to eq(new_client.id)
      expect(response).to redirect_to(bl_house_lines_url)
    end

    it "renders reassign when required params are missing" do
      sign_in user, scope: :user

      patch perform_reassign_bl_house_line_url(bl_house_line), params: {
        reassign: {
          new_customs_agent_id: new_agent.id,
          new_client_id: new_client.id
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  describe "PATCH /bl_house_lines/:id/approve_revalidation" do
    let(:user) { create(:user, :executive) }
    let(:customs_agent) { create(:entity, :customs_agent) }
    let(:customs_broker) { create(:entity, :customs_broker) }
    let(:container) { create(:container) }
    let(:bl_house_line) { create(:bl_house_line, container: container, customs_agent: customs_agent, status: "validar_documentos") }

    before do
      sign_in user, scope: :user

      create(:consolidator, entity: container.consolidator_entity)

      container.consolidator_entity.update!(
        requires_bl_endosado_documento: true,
        requires_liberacion_documento: false,
        requires_encomienda_documento: false,
        requires_pago_documento: false
      )

      AgencyBroker.create!(agency: customs_agent, broker: customs_broker)
      container.tarja_documento.attach(io: StringIO.new("tarja"), filename: "tarja.pdf", content_type: "application/pdf")
    end

    it "aprueba cuando todos los documentos requeridos del consolidador están validados" do
      patch approve_revalidation_bl_house_line_url(bl_house_line), params: {
        decision: "assign",
        bl_house_line: {
          customs_agent_id: customs_agent.id,
          customs_broker_id: customs_broker.id,
          bl_endosado_documento_validated: "1",
          liberacion_documento_validated: "0",
          encomienda_documento_validated: "0",
          pago_documento_validated: "0"
        }
      }

      expect(response).to have_http_status(:found)
      expect(bl_house_line.reload.status).to eq("revalidado")
    end

    it "rechaza cuando falta validar un documento requerido del consolidador" do
      patch approve_revalidation_bl_house_line_url(bl_house_line), params: {
        decision: "assign",
        bl_house_line: {
          customs_agent_id: customs_agent.id,
          customs_broker_id: customs_broker.id,
          bl_endosado_documento_validated: "0",
          liberacion_documento_validated: "1",
          encomienda_documento_validated: "1",
          pago_documento_validated: "1"
        }
      }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Debes marcar todos los documentos como validados antes de continuar.")
      expect(bl_house_line.reload.status).to eq("validar_documentos")
    end
  end

  describe "dispatch modal success confirmation" do
    before { sign_in user, scope: :user }

    it "renders success modal with update list button" do
      bl_house_line = create(:bl_house_line, status: "revalidado")

      patch update_dispatch_date_bl_house_line_url(bl_house_line),
            params: { bl_house_line: { fecha_despacho: Time.current.change(sec: 0) } },
            headers: { "ACCEPT" => "text/vnd.turbo-stream.html" }

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Despacho registrado")
      expect(response.body).to include("Actualizar listado")
      expect(bl_house_line.reload.status).to eq("despachado")
    end
  end

  describe "approval link visibility" do
    before { sign_in user, scope: :user }

    it "does not render approval link for revalidado" do
      bl_house_line = create(:bl_house_line, status: "revalidado")

      get bl_house_lines_url

      expect(response.body).not_to include(revalidation_approval_bl_house_line_path(bl_house_line))
    end

    it "does not render approval link for despachado" do
      bl_house_line = create(:bl_house_line, status: "despachado")

      get bl_house_lines_url

      expect(response.body).not_to include(revalidation_approval_bl_house_line_path(bl_house_line))
    end
  end
end
