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

    it "returns containers updated since the inclusive timestamp in ascending order" do
      since = Time.utc(2026, 9, 1, 12)
      later = create(:container, consolidator_entity: entity)
      boundary = create(:container, consolidator_entity: entity)
      earlier = create(:container, consolidator_entity: entity)
      later.update_column(:updated_at, since + 1.hour)
      boundary.update_column(:updated_at, since)
      earlier.update_column(:updated_at, since - 1.second)

      get api_v1_consolidator_containers_path,
          params: { updated_since: since.iso8601 },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") })
        .to eq([ boundary.id, later.id ])
    end

    it "rejects updated_since combined with a date range" do
      get api_v1_consolidator_containers_path,
          params: {
            updated_since: 1.hour.ago.utc.iso8601,
            date_from: Date.current.iso8601,
            date_to: Date.current.iso8601
          },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_parameter")
    end

    it "rejects updated_since values that are not explicit UTC timestamps" do
      get api_v1_consolidator_containers_path,
          params: { updated_since: "2026-09-01T12:00:00-05:00" },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_parameter")
    end

    it "uses a stable cursor window when a returned container changes between pages" do
      since = 1.day.ago.utc
      first = create(:container, consolidator_entity: entity)
      second = create(:container, consolidator_entity: entity)
      third = create(:container, consolidator_entity: entity)
      first.update_column(:updated_at, since + 1.minute)
      second.update_column(:updated_at, since + 2.minutes)
      third.update_column(:updated_at, since + 3.minutes)

      get api_v1_consolidator_containers_path,
          params: { updated_since: since.iso8601, per_page: 2 },
          headers: headers

      first_page = response.parsed_body
      expect(first_page.fetch("data").map { |item| item.fetch("id") }).to eq([ first.id, second.id ])
      cursor = first_page.dig("meta", "next_cursor")
      sync_until = Time.iso8601(first_page.dig("meta", "sync_until"))
      expect(cursor).to be_present

      first.update_column(:updated_at, sync_until - 1.second)

      get api_v1_consolidator_containers_path,
          params: { cursor: cursor, per_page: 2 },
          headers: headers

      second_page = response.parsed_body
      expect(second_page.fetch("data").map { |item| item.fetch("id") }).to eq([ third.id, first.id ])
      expect(second_page.dig("meta", "sync_until")).to eq(first_page.dig("meta", "sync_until"))
      expect(second_page.dig("meta", "next_cursor")).to be_nil
    end

    it "rejects a cursor combined with updated_since" do
      get api_v1_consolidator_containers_path,
          params: { cursor: "invalid", updated_since: 1.hour.ago.utc.iso8601 },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_parameter")
    end

    it "rejects an invalid cursor" do
      get api_v1_consolidator_containers_path,
          params: { cursor: "invalid" },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_parameter")
    end

    it "rejects page when continuing a cursor request" do
      since = 1.day.ago.utc
      create_list(:container, 2, consolidator_entity: entity).each_with_index do |container, index|
        container.update_column(:updated_at, since + (index + 1).minutes)
      end

      get api_v1_consolidator_containers_path,
          params: { updated_since: since.iso8601, per_page: 1 },
          headers: headers
      cursor = response.parsed_body.dig("meta", "next_cursor")

      get api_v1_consolidator_containers_path,
          params: { cursor: cursor, per_page: 1, page: 2 },
          headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "code")).to eq("invalid_parameter")
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

  describe "GET /api/v1/consolidator/bl_house_lines" do
    it "returns only owned lines updated since the inclusive timestamp in ascending order" do
      since = Time.utc(2026, 9, 1, 12)
      container = create(:container, consolidator_entity: entity)
      other_container = create(:container, consolidator_entity: other_entity)
      later = create(:bl_house_line, container: container)
      boundary = create(:bl_house_line, container: container)
      boundary_tie = create(:bl_house_line, container: container)
      earlier = create(:bl_house_line, container: container)
      create(:bl_house_line, container: other_container)
      later.update_column(:updated_at, since + 1.hour)
      boundary.update_column(:updated_at, since)
      boundary_tie.update_column(:updated_at, since)
      earlier.update_column(:updated_at, since - 1.second)

      get api_v1_consolidator_bl_house_lines_path,
          params: { updated_since: since.iso8601 },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") })
        .to eq([ boundary.id, boundary_tie.id, later.id ])
    end

    it "supports a bounded historical date range" do
      container = create(:container, consolidator_entity: entity)
      matching = create(:bl_house_line, container: container, created_at: 2.days.ago)
      create(:bl_house_line, container: container, created_at: 10.days.ago)

      get api_v1_consolidator_bl_house_lines_path,
          params: { date_from: 3.days.ago.to_date.iso8601, date_to: Date.current.iso8601 },
          headers: headers

      expect(response).to have_http_status(:ok)
      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to eq([ matching.id ])
    end

    it "rejects an unbounded global listing" do
      get api_v1_consolidator_bl_house_lines_path, headers: headers

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body.dig("error", "message")).to eq("date_from and date_to are required")
    end

    it "continues an incremental line listing with its signed cursor" do
      since = 1.day.ago.utc
      container = create(:container, consolidator_entity: entity)
      first = create(:bl_house_line, container: container)
      second = create(:bl_house_line, container: container)
      first.update_column(:updated_at, since + 1.minute)
      second.update_column(:updated_at, since + 2.minutes)

      get api_v1_consolidator_bl_house_lines_path,
          params: { updated_since: since.iso8601, per_page: 1 },
          headers: headers

      first_page = response.parsed_body
      expect(first_page.fetch("data").map { |item| item.fetch("id") }).to eq([ first.id ])

      get api_v1_consolidator_bl_house_lines_path,
          params: { cursor: first_page.dig("meta", "next_cursor"), per_page: 1 },
          headers: headers

      expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to eq([ second.id ])
    end
  end

  describe "change propagation to container timestamps" do
    it "touches the container when a bl house line changes" do
      container = create(:container, consolidator_entity: entity)
      line = create(:bl_house_line, container: container)
      old_updated_at = 1.day.ago
      container.update_column(:updated_at, old_updated_at)

      line.update!(contiene: "Actualizado")

      expect(container.reload.updated_at).to be > old_updated_at
    end
  end
end
