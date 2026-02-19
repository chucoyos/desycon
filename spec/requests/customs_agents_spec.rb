require 'rails_helper'

RSpec.describe "CustomsAgents", type: :request do
  let(:customs_user) { create(:user, :customs_broker) }
  let(:assigned_bl_house_line) { create(:bl_house_line, customs_agent: customs_user.entity) }
  let(:unassigned_bl_house_line) { create(:bl_house_line, customs_agent: nil) }

  describe "GET /dashboard" do
    it "returns http success for authenticated customs agent" do
      sign_in customs_user, scope: :user
      get customs_agents_dashboard_path
      expect(response).to have_http_status(:success)
    end

    it "redirects unauthenticated users" do
      get customs_agents_dashboard_path
      expect(response).to have_http_status(:redirect)
    end

    it "redirects non-customs agent users" do
      executive_user = create(:user, :executive)
      sign_in executive_user, scope: :user
      get customs_agents_dashboard_path
      expect(response).to have_http_status(:redirect)
    end

    it "shows assigned BL House Lines" do
      assigned_bl_house_line
      sign_in customs_user, scope: :user
      get customs_agents_dashboard_path
      expect(response.body).to include(assigned_bl_house_line.blhouse)
    end

    it "does not show unassigned BL House Lines" do
      unassigned_bl_house_line
      sign_in customs_user, scope: :user
      get customs_agents_dashboard_path
      expect(response.body).not_to include(unassigned_bl_house_line.blhouse)
    end

    context "search by blhouse" do
      it "redirects to edit when blhouse is found and assigned" do
        assigned_bl_house_line
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: assigned_bl_house_line.blhouse }
        expect(response).to redirect_to(edit_bl_house_line_path(assigned_bl_house_line))
      end

      it "redirects to edit when blhouse is found and unassigned" do
        unassigned_bl_house_line
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: unassigned_bl_house_line.blhouse }
        expect(response).to redirect_to(edit_bl_house_line_path(unassigned_bl_house_line))
      end

      it "shows alert when blhouse is not found" do
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: "NONEXISTENT" }
        expect(response).to have_http_status(:success)
        expect(flash[:alert]).to eq("BL House no encontrado.")
      end

      it "ignores case and strips whitespace in search" do
        assigned_bl_house_line
        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path, params: { blhouse: " #{assigned_bl_house_line.blhouse.downcase} " }
        expect(response).to redirect_to(edit_bl_house_line_path(assigned_bl_house_line))
      end
    end

    context "revalidation link visibility" do
      it "hides revalidation link for revalidado status" do
        bl = create(:bl_house_line, customs_agent: customs_user.entity, status: "revalidado")

        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path

        expect(response.body).not_to include(customs_agents_revalidation_path(revalidation_blhouse: bl.blhouse))
      end

      it "hides revalidation link for despachado status" do
        bl = create(:bl_house_line, customs_agent: customs_user.entity, status: "despachado")

        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path

        expect(response.body).not_to include(customs_agents_revalidation_path(revalidation_blhouse: bl.blhouse))
      end

      it "shows revalidation link for non-revalidated statuses" do
        bl = create(:bl_house_line, customs_agent: customs_user.entity, status: "activo")

        sign_in customs_user, scope: :user
        get customs_agents_dashboard_path

        expect(response.body).to include(customs_agents_revalidation_path(revalidation_blhouse: bl.blhouse))
      end
    end
  end

  describe "GET /revalidations" do
    let(:headers) { { "Turbo-Frame" => "revalidation_modal" } }

    it "returns http success when blhouse is found" do
      sign_in customs_user, scope: :user
      get customs_agents_revalidation_path, params: { blhouse: unassigned_bl_house_line.blhouse }, headers: headers
      expect(response).to have_http_status(:success)
    end

    it "returns not found when blhouse is missing" do
      sign_in customs_user, scope: :user
      get customs_agents_revalidation_path, params: { blhouse: "NONEXISTENT" }, headers: headers
      expect(response).to have_http_status(:not_found)
    end
  end

  describe "PATCH /revalidations/:id" do
    let(:headers) { { "Turbo-Frame" => "revalidation_modal" } }
    let(:customs_agent) { customs_user.entity }
    let(:client) { create(:entity, :client, customs_agent: customs_agent) }

    it "assigns the customs agent and client when blank" do
      bl_house_line = create(:bl_house_line, customs_agent: nil, client: nil)

      sign_in customs_user, scope: :user
      patch customs_agents_revalidation_update_path(bl_house_line),
        params: { bl_house_line: { client_id: client.id } },
        headers: headers

      bl_house_line.reload
      expect(bl_house_line.customs_agent_id).to eq(customs_agent.id)
      expect(bl_house_line.client_id).to eq(client.id)
      expect(bl_house_line.status).to eq("validar_documentos")
      expect(response).to have_http_status(:success)
    end

    it "keeps the original client when already assigned" do
      original_client = create(:entity, :client, customs_agent: customs_agent)
      other_client = create(:entity, :client, customs_agent: customs_agent)
      bl_house_line = create(:bl_house_line, customs_agent: nil, client: original_client)

      sign_in customs_user, scope: :user
      patch customs_agents_revalidation_update_path(bl_house_line),
        params: { bl_house_line: { client_id: other_client.id } },
        headers: headers

      bl_house_line.reload
      expect(bl_house_line.client_id).to eq(original_client.id)
      expect(bl_house_line.status).to eq("validar_documentos")
      expect(response).to have_http_status(:success)
    end
  end
end
