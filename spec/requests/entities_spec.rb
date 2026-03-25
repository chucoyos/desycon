require 'rails_helper'

RSpec.describe "Entities", type: :request do
  let(:user) { create(:user, :admin) }
  let(:entity) { create(:entity) }

  before do
    sign_in user, scope: :user
  end

  describe "GET /index" do
    let!(:consolidator) { create(:entity, :consolidator, name: "ABC Consolidators") }
    let!(:customs_agent) { create(:entity, :customs_agent, name: "XYZ Customs") }
    let!(:forwarder) { create(:entity, :forwarder, name: "Fast Forwarder") }
    let!(:client) { create(:entity, :client, name: "Client Company") }

    it "returns http success" do
      get entities_path
      expect(response).to have_http_status(:success)
    end

    it "filters by name" do
      get entities_path, params: { name: "ABC" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("ABC Consolidators")
      expect(response.body).not_to include("XYZ Customs")
    end

    it "filters by role consolidator" do
      get entities_path, params: { role: "consolidator" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("ABC Consolidators")
      expect(response.body).not_to include("XYZ Customs")
    end

    it "filters by role customs_agent" do
      get entities_path, params: { role: "customs_agent" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("XYZ Customs")
      expect(response.body).not_to include("ABC Consolidators")
    end

    it "filters by role forwarder" do
      get entities_path, params: { role: "forwarder" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Fast Forwarder")
      expect(response.body).not_to include("ABC Consolidators")
    end

    it "filters by role client" do
      get entities_path, params: { role: "client" }
      expect(response).to have_http_status(:success)
      expect(response.body).to include("Client Company")
    end
  end

  describe "GET /show" do
    it "returns http success" do
      get entity_path(entity)
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /new" do
    it "returns http success" do
      get new_entity_path
      expect(response).to have_http_status(:success)
    end
  end

  describe "GET /entities/countries_search" do
    it "returns filtered countries for valid query" do
      get countries_search_entities_path, params: { q: "mex" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).not_to be_empty
      expect(payload["results"].map { |result| result["id"] }).to include("MX")
    end

    it "returns empty results when query length is below min chars" do
      get countries_search_entities_path, params: { q: "m" }

      expect(response).to have_http_status(:ok)
      payload = JSON.parse(response.body)
      expect(payload["results"]).to eq([])
      expect(payload["meta"]).to include("min_chars" => 2)
    end
  end

  describe "GET /edit" do
    it "returns http success" do
      get edit_entity_path(entity)
      expect(response).to have_http_status(:success)
    end
  end

  describe "POST /create" do
    it "creates an entity with valid params" do
      expect {
        post entities_path, params: {
          entity: {
            name: "Nueva Entidad",
            role_kind: "client"
          }
        }
      }.to change(Entity, :count).by(1)

      created = Entity.order(:id).last
      expect(response).to redirect_to(entity_path(created))
      expect(flash[:notice]).to eq("Entidad creada exitosamente.")
      expect(created.name).to eq("Nueva Entidad")
      expect(created.role_kind).to eq("client")
    end

    it "returns unprocessable_content with invalid params" do
      expect {
        post entities_path, params: {
          entity: {
            name: "",
            role_kind: "client"
          }
        }
      }.not_to change(Entity, :count)

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "creates customs agency with multiple email recipients" do
      expect {
        post entities_path, params: {
          entity: {
            name: "Agencia con Correos",
            role_kind: "customs_agent",
            entity_email_recipients_attributes: {
              "0" => { email: "agencia1@correo.com", position: "0", primary_recipient: "1", active: "1" },
              "1" => { email: "agencia2@correo.com", position: "1", primary_recipient: "0", active: "1" }
            }
          }
        }
      }.to change(EntityEmailRecipient, :count).by(2)

      created = Entity.order(:id).last
      expect(created.role_kind).to eq("customs_agent")
      expect(created.delivery_email_recipients).to eq([ "agencia1@correo.com", "agencia2@correo.com" ])
    end
  end

  describe "PATCH /update" do
    let!(:fiscal_profile) { create(:fiscal_profile, profileable: entity, razon_social: "Razon Original") }

    it "updates entity name" do
      patch entity_path(entity), params: {
        entity: {
          name: "Entidad Renombrada"
        }
      }

      expect(response).to redirect_to(entity_path(entity))
      expect(flash[:notice]).to eq("Entidad actualizada exitosamente.")
      expect(entity.reload.name).to eq("Entidad Renombrada")
    end

    it "allows admin to update overdue-rule toggle" do
      agency = create(:entity, :customs_agent, enforce_overdue_payment_rule: true)

      patch entity_path(agency), params: {
        entity: {
          enforce_overdue_payment_rule: false
        }
      }

      expect(response).to redirect_to(entity_path(agency))
      expect(agency.reload.enforce_overdue_payment_rule).to eq(false)
    end

    it "updates fiscal profile through nested attributes" do
      patch entity_path(entity), params: {
        entity: {
          fiscal_profile_attributes: {
            id: fiscal_profile.id,
            razon_social: "Razon Actualizada"
          }
        }
      }

      expect(response).to redirect_to(entity_path(entity))
      expect(flash[:notice]).to eq("Entidad actualizada exitosamente.")
      expect(entity.reload.fiscal_profile.razon_social).to eq("Razon Actualizada")
    end

    it "updates consolidator email recipients through nested attributes" do
      consolidator = create(:entity, :consolidator)
      existing = create(:entity_email_recipient, :primary, entity: consolidator, email: "old@correo.com", position: 0)

      patch entity_path(consolidator), params: {
        entity: {
          entity_email_recipients_attributes: {
            "0" => {
              id: existing.id,
              email: "principal@correo.com",
              position: "0",
              primary_recipient: "1",
              active: "1"
            },
            "1" => {
              email: "secundario@correo.com",
              position: "1",
              primary_recipient: "0",
              active: "1"
            }
          }
        }
      }

      expect(response).to redirect_to(entity_path(consolidator))
      expect(consolidator.reload.delivery_email_recipients).to eq([ "principal@correo.com", "secundario@correo.com" ])
    end

    it "removes an email recipient using _destroy" do
      agency = create(:entity, :customs_agent)
      recipient = create(:entity_email_recipient, entity: agency, email: "remove@correo.com")

      expect {
        patch entity_path(agency), params: {
          entity: {
            entity_email_recipients_attributes: {
              "0" => {
                id: recipient.id,
                _destroy: "1"
              }
            }
          }
        }
      }.to change(EntityEmailRecipient, :count).by(-1)

      expect(response).to redirect_to(entity_path(agency))
    end
  end

  describe "DELETE /destroy" do
    it "deletes entity without dependent users" do
      entity_to_delete = create(:entity)

      expect {
        delete entity_path(entity_to_delete)
      }.to change(Entity, :count).by(-1)

      expect(response).to redirect_to(entities_path)
      expect(flash[:notice]).to eq("Entidad eliminada exitosamente.")
    end

    it "does not delete when entity has users" do
      create(:user, entity: entity)

      expect {
        delete entity_path(entity)
      }.not_to change(Entity, :count)

      expect(response).to redirect_to(entities_path)
      expect(flash[:alert]).to be_present
    end
  end

  describe "authorization for customs broker users" do
    let(:customs_broker_user) { create(:user, :customs_broker) }

    before do
      sign_out user
      sign_in customs_broker_user, scope: :user
    end

    it "blocks updating a client that does not belong to the customs agent" do
      foreign_client = create(:entity, :client)

      patch entity_path(foreign_client), params: {
        entity: { name: "No autorizado" }
      }

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(foreign_client.reload.name).not_to eq("No autorizado")
    end

    it "allows updating own client" do
      own_client = create(:entity, :client, customs_agent: customs_broker_user.entity)

      patch entity_path(own_client), params: {
        entity: { name: "Cliente Propio" }
      }

      expect(response).to redirect_to(entity_path(own_client))
      expect(own_client.reload.name).to eq("Cliente Propio")
    end

    it "blocks managing customs brokers (agents)" do
      customs_broker_entity = create(:entity, :customs_broker)

      patch entity_path(customs_broker_entity), params: {
        entity: { name: "No deberia" }
      }

      expect(response).to redirect_to(customs_agents_dashboard_path)
      expect(customs_broker_entity.reload.name).not_to eq("No deberia")
    end

    it "does not allow customs broker to modify overdue-rule toggle by forged request" do
      own_client = create(:entity, :client, customs_agent: customs_broker_user.entity)

      patch entity_path(own_client), params: {
        entity: {
          enforce_overdue_payment_rule: false,
          name: "Cliente Propio"
        }
      }

      expect(response).to redirect_to(entity_path(own_client))
      expect(own_client.reload.name).to eq("Cliente Propio")
      expect(own_client.enforce_overdue_payment_rule).to eq(true)
    end

    it "ignores patent assignment when creating a client" do
      expect {
        post entities_path, params: {
          entity: {
            name: "Cliente Agencia",
            role_kind: "customs_broker",
            patent_number: "9999"
          }
        }
      }.to change(Entity, :count).by(1)

      created = Entity.order(:id).last
      expect(response).to redirect_to(entity_path(created))
      expect(created.role_kind).to eq("client")
      expect(created.customs_agent_id).to eq(customs_broker_user.entity_id)
      expect(created.patent_number).to be_nil
    end
  end
end
