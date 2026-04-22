require "rails_helper"

RSpec.describe Photos::BuildArchiveJob, type: :job do
  describe "#perform" do
    it "stores a non-empty zip and marks request as completed" do
      user = create(:user, :admin)
      bl_house_line = create(:bl_house_line)

      create_list(:photo, 3, :etiquetado, attachable: bl_house_line)

      request = create(
        :photo_archive_request,
        attachable: bl_house_line,
        requested_by: user,
        section: "etiquetado",
        status: :pending
      )

      described_class.perform_now(request.id)

      request.reload
      expect(request.status).to eq("completed")
      expect(request.archive).to be_attached
      expect(request.archive.blob.byte_size).to be > Photos::BuildArchiveJob::EMPTY_ZIP_MIN_BYTES
      expect(request.archive.blob.filename.to_s).to end_with(".zip")
    end
  end
end
