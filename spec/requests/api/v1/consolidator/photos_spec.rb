require "rails_helper"

RSpec.describe "Consolidator photos API", type: :request do
  let(:entity) { create(:entity, :consolidator) }
  let(:other_entity) { create(:entity, :consolidator) }
  let(:api_key) { ConsolidatorApiCredential.issue!(entity: entity, name: "Photo integration").last }
  let(:headers) { { "Authorization" => "Bearer #{api_key}", "Accept" => "application/json" } }

  it "returns photo metadata and a download URL for an owned container" do
    container = create(:container, consolidator_entity: entity)
    photo = create(:photo, attachable: container, section: "apertura")

    get api_v1_consolidator_container_photos_path(container), headers: headers

    expect(response).to have_http_status(:ok)
    item = response.parsed_body.fetch("data").first
    expect(item.fetch("id")).to eq(photo.id)
    expect(item.fetch("filename")).to eq(photo.image.filename.to_s)
    expect(item.fetch("download_url")).to include("/rails/active_storage/")
    expect(item.fetch("expires_at")).to be_nil
    expect(item).not_to have_key("data")
  end

  it "returns a presigned S3 URL with expiration for Amazon-backed photos" do
    container = create(:container, consolidator_entity: entity)
    photo = create(:photo, attachable: container, section: "apertura")
    s3_service = double("S3Service")
    allow_any_instance_of(ActiveStorage::Blob).to receive(:service_name).and_return("amazon")
    allow_any_instance_of(ActiveStorage::Blob).to receive(:service).and_return(s3_service)
    allow(s3_service).to receive(:url).and_return("https://s3.example.test/photo?signature=temporary")

    get api_v1_consolidator_container_photos_path(container), headers: headers

    expect(response).to have_http_status(:ok)
    item = response.parsed_body.fetch("data").first
    expect(item.fetch("download_url")).to eq("https://s3.example.test/photo?signature=temporary")
    expect(Time.iso8601(item.fetch("expires_at"))).to be_within(10.seconds).of(5.minutes.from_now)
  end

  it "does not expose photos from another consolidator" do
    container = create(:container, consolidator_entity: other_entity)
    create(:photo, attachable: container, section: "apertura")

    get api_v1_consolidator_container_photos_path(container), headers: headers

    expect(response).to have_http_status(:not_found)
  end

  it "returns etiquetado photos for an owned bl house line" do
    container = create(:container, consolidator_entity: entity)
    line = create(:bl_house_line, container: container)
    photo = create(:photo, attachable: line, section: "etiquetado")

    get api_v1_consolidator_container_bl_house_line_photos_path(container, line), headers: headers

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.fetch("data").map { |item| item.fetch("id") }).to contain_exactly(photo.id)
  end
end
