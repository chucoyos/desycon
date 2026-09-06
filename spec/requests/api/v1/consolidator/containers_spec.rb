require "rails_helper"

RSpec.describe "Consolidator containers API", type: :request do
  let(:entity) { create(:entity, :consolidator) }
  let(:other_entity) { create(:entity, :consolidator) }
  let(:credential_and_key) { ConsolidatorApiCredential.issue!(entity: entity, name: "Test integration") }
  let(:api_key) { credential_and_key.last }
  let(:headers) { { "Authorization" => "Bearer #{api_key}", "Accept" => "application/json" } }

  describe "GET /api/v1/consolidator/containers" do
    it "requires a valid API key" do
      get api_v1_consolidator_containers_path, headers: { "Accept" => "application/json" }

      expect(response).to have_http_status(:unauthorized)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_api_key")
    end

    it "returns only containers assigned to the API key entity" do
      own_container = create(:container, consolidator_entity: entity)
      create(:container, consolidator_entity: other_entity)

      get api_v1_consolidator_containers_path,
          params: { date_from: 1.day.ago.to_date.iso8601, date_to: Date.current.iso8601 },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |container| container.fetch("id") })
        .to contain_exactly(own_container.id)
    end

    it "applies status, date and pagination filters" do
      matching = create(:container, consolidator_entity: entity, status: "en_proceso_desconsolidacion", created_at: 2.days.ago)
      create(:container, consolidator_entity: entity, status: "activo", created_at: 1.day.ago)
      create(:container, consolidator_entity: entity, status: "en_proceso_desconsolidacion", created_at: 10.days.ago)

      get api_v1_consolidator_containers_path,
          params: {
            status: "en_proceso_desconsolidacion",
            date_from: 3.days.ago.to_date.iso8601,
            date_to: Date.current.iso8601,
            page: 1,
            per_page: 1
          },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |container| container.fetch("id") })
        .to contain_exactly(matching.id)
      expect(response.parsed_body.dig("meta", "total_count")).to eq(1)
      expect(response.parsed_body.dig("meta", "per_page")).to eq(1)
    end

    it "rejects invalid date parameters" do
      get api_v1_consolidator_containers_path,
          params: { date_from: "not-a-date" },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_parameter")
    end

    it "requires a complete date range" do
      get api_v1_consolidator_containers_path,
          params: { date_from: 1.day.ago.to_date.iso8601 },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "message")).to eq("date_from and date_to are required")
    end

    it "rejects an inverted date range" do
      get api_v1_consolidator_containers_path,
          params: { date_from: Date.current.iso8601, date_to: 1.day.ago.to_date.iso8601 },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "message")).to eq("date_from must be on or before date_to")
    end
  end

  describe "GET /api/v1/consolidator/containers/:container_id/bl_house_lines" do
    it "returns only the lines for an owned container" do
      container = create(:container, consolidator_entity: entity)
      line = create(:bl_house_line, container: container)

      get api_v1_consolidator_container_bl_house_lines_path(container), headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to contain_exactly(line.id)
    end

    it "does not reveal a container owned by another consolidator" do
      container = create(:container, consolidator_entity: other_entity)

      get api_v1_consolidator_container_bl_house_lines_path(container), headers: headers

      expect(response).to have_http_status(:not_found)
      expect(response.parsed_body.dig("error", "code")).to eq("not_found")
    end
  end
end
