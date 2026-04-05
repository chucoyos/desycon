require "rails_helper"

RSpec.describe "Photos", type: :request do
  describe "POST /containers/:id/photos" do
    let(:container) { create(:container) }

    it "allows admin users to upload container photos" do
      admin = create(:user, :admin)
      login_as admin

      expect {
        post photos_container_path(container), params: {
          photo: {
            section: "apertura",
            images: [ uploaded_image("admin.jpg") ]
          }
        }
      }.to change(Photo, :count).by(1)

      expect(response).to redirect_to(container_path(container))
    end

    it "prevents customs broker users from uploading photos" do
      broker = create(:user, :customs_broker)
      login_as broker

      expect {
        post photos_container_path(container), params: {
          photo: {
            section: "apertura",
            images: [ uploaded_image("broker.jpg") ]
          }
        }
      }.not_to change(Photo, :count)

      expect(response).to have_http_status(:found)
    end

    it "allows tramitador users to upload container photos" do
      tramitador = create(:user, :tramitador)
      login_as tramitador

      expect {
        post photos_container_path(container), params: {
          photo: {
            section: "apertura",
            images: [ uploaded_image("tramitador.jpg") ]
          }
        }
      }.to change(Photo, :count).by(1)

      expect(response).to redirect_to(container_path(container))
    end
  end

  describe "POST /bl_house_lines/:id/photos" do
    let(:bl_house_line) { create(:bl_house_line) }

    it "allows executive users to upload etiquetado photos" do
      executive = create(:user, :executive)
      login_as executive

      expect {
        post photos_bl_house_line_path(bl_house_line), params: {
          photo: {
            section: "etiquetado",
            images: [ uploaded_image("exec.jpg") ]
          }
        }
      }.to change(Photo, :count).by(1)

      expect(response).to redirect_to(bl_house_line_path(bl_house_line))
    end
  end

  describe "DELETE /photos/:id" do
    it "allows admin users to delete photos" do
      admin = create(:user, :admin)
      login_as admin

      photo = create(:photo)

      expect {
        delete photo_path(photo)
      }.to change(Photo, :count).by(-1)

      expect(response).to have_http_status(:found)
    end

    it "allows tramitador users to delete photos" do
      tramitador = create(:user, :tramitador)
      login_as tramitador

      photo = create(:photo)

      expect {
        delete photo_path(photo)
      }.to change(Photo, :count).by(-1)

      expect(response).to have_http_status(:found)
    end
  end

  describe "DELETE /containers/:id/photos_section" do
    let(:container) { create(:container) }

    it "deletes only photos from the selected section" do
      admin = create(:user, :admin)
      login_as admin

      create(:photo, attachable: container, section: "apertura")
      create(:photo, attachable: container, section: "apertura")
      create(:photo, attachable: container, section: "vacio")

      expect {
        delete photos_section_container_path(container), params: { photo: { section: "apertura" } }
      }.to change { container.photos.for_section("apertura").count }.from(2).to(0)

      expect(container.photos.for_section("vacio").count).to eq(1)
      expect(response).to redirect_to(container_path(container))
    end
  end

  describe "DELETE /bl_house_lines/:id/photos_section" do
    let(:bl_house_line) { create(:bl_house_line) }

    it "deletes etiquetado photos for executive users" do
      executive = create(:user, :executive)
      login_as executive

      create(:photo, :etiquetado, attachable: bl_house_line)
      create(:photo, :etiquetado, attachable: bl_house_line)

      expect {
        delete photos_section_bl_house_line_path(bl_house_line), params: { photo: { section: "etiquetado" } }
      }.to change { bl_house_line.photos.for_section("etiquetado").count }.from(2).to(0)

      expect(response).to redirect_to(bl_house_line_path(bl_house_line))
    end
  end

  describe "GET /containers/:id/photos_download" do
    let(:container) { create(:container) }

    it "downloads a zip with photos from the selected section" do
      admin = create(:user, :admin)
      login_as admin

      create(:photo, attachable: container, section: "apertura")
      create(:photo, attachable: container, section: "apertura")
      create(:photo, attachable: container, section: "vacio")

      get photos_download_container_path(container, section: "apertura")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("contenedor")
      expect(response.headers["Content-Disposition"]).to include("apertura")
    end
  end

  describe "GET /bl_house_lines/:id/photos_download" do
    let(:bl_house_line) { create(:bl_house_line) }

    it "downloads a zip with etiquetado photos" do
      executive = create(:user, :executive)
      login_as executive

      create(:photo, :etiquetado, attachable: bl_house_line)
      create(:photo, :etiquetado, attachable: bl_house_line)

      get photos_download_bl_house_line_path(bl_house_line, section: "etiquetado")

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("partida")
      expect(response.headers["Content-Disposition"]).to include("etiquetado")
    end
  end

  describe "GET /containers/:id/photos_download_all" do
    let(:container) { create(:container) }

    it "downloads a zip with photos from all sections" do
      admin = create(:user, :admin)
      login_as admin

      create(:photo, attachable: container, section: "apertura")
      create(:photo, attachable: container, section: "vacio")

      get photos_download_all_container_path(container)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("todas_las_secciones")
    end

    it "allows consolidator users to download photos from their own container" do
      consolidator_user = create(:user, :consolidator)
      login_as consolidator_user

      owned_container = create(:container, consolidator_entity: consolidator_user.entity)
      create(:photo, attachable: owned_container, section: "apertura")

      get photos_download_all_container_path(owned_container)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
    end

    it "prevents consolidator users from downloading photos from other consolidators' containers" do
      consolidator_user = create(:user, :consolidator)
      login_as consolidator_user

      other_container = create(:container)
      create(:photo, attachable: other_container, section: "apertura")

      get photos_download_all_container_path(other_container)

      expect(response).to have_http_status(:found)
    end
  end

  describe "GET /bl_house_lines/:id/photos_download_all" do
    let(:bl_house_line) { create(:bl_house_line) }

    it "downloads a zip with all partida photos" do
      executive = create(:user, :executive)
      login_as executive

      create(:photo, :etiquetado, attachable: bl_house_line)

      get photos_download_all_bl_house_line_path(bl_house_line)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
      expect(response.headers["Content-Disposition"]).to include("attachment")
      expect(response.headers["Content-Disposition"]).to include("todas_las_secciones")
    end

    it "allows consolidator users to download photos from their own partida" do
      consolidator_user = create(:user, :consolidator)
      login_as consolidator_user

      owned_container = create(:container, consolidator_entity: consolidator_user.entity)
      owned_bl_house_line = create(:bl_house_line, container: owned_container)
      create(:photo, :etiquetado, attachable: owned_bl_house_line)

      get photos_download_all_bl_house_line_path(owned_bl_house_line)

      expect(response).to have_http_status(:ok)
      expect(response.media_type).to eq("application/zip")
    end

    it "prevents consolidator users from downloading photos from other consolidators' partidas" do
      consolidator_user = create(:user, :consolidator)
      login_as consolidator_user

      other_bl_house_line = create(:bl_house_line)
      create(:photo, :etiquetado, attachable: other_bl_house_line)

      get photos_download_all_bl_house_line_path(other_bl_house_line)

      expect(response).to have_http_status(:found)
    end
  end

  private

  def uploaded_image(filename)
    tempfile = Tempfile.new([ File.basename(filename, ".jpg"), ".jpg" ])
    tempfile.binmode
    tempfile.write("fake-image-content")
    tempfile.rewind

    Rack::Test::UploadedFile.new(tempfile.path, "image/jpeg", original_filename: filename)
  end
end
