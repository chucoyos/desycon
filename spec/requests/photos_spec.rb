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
