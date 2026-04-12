class Photos::BuildArchiveJob < ApplicationJob
  queue_as :default

  discard_on ActiveJob::DeserializationError

  def perform(photo_archive_request_id)
    request = PhotoArchiveRequest.find_by(id: photo_archive_request_id)
    return unless request

    request.mark_processing!

    attachable = request.attachable
    return request.mark_failed!("Registro adjuntable no encontrado") unless attachable

    photos = photos_for_request(request: request, attachable: attachable)
    return request.mark_failed!("No hay fotografias para generar el ZIP") if photos.empty?

    zip_file = build_zip_file(photos: photos)

    request.archive.attach(
      io: zip_file,
      filename: zip_filename_for(attachable: attachable, section: request.section),
      content_type: "application/zip"
    )

    request.mark_completed!(photos_count: photos.size)
  rescue StandardError => e
    request&.mark_failed!(e.message)
    Rails.logger.error("[Photos::BuildArchiveJob] request_id=#{photo_archive_request_id} error=#{e.class}: #{e.message}")
  ensure
    if defined?(zip_file) && zip_file
      zip_file.close
      zip_file.unlink
    end
  end

  private

  def photos_for_request(request:, attachable:)
    scope = attachable.photos.recent.includes(image_attachment: :blob)
    scope = scope.for_section(request.section) unless request.section == PhotoArchiveRequest::SECTION_ALL

    scope.select { |photo| photo.image.attached? }
  end

  def build_zip_file(photos:)
    require "zip"
    require "fileutils"
    require "tempfile"

    export_dir = Rails.root.join("tmp", "photo_exports")
    FileUtils.mkdir_p(export_dir)

    zip_file = Tempfile.new([ "photo_archive_", ".zip" ], export_dir)
    zip_file.binmode

    Zip::File.open(zip_file.path, create: true) do |zip|
      photos.each_with_index do |photo, index|
        blob = photo.image.blob
        extension = File.extname(blob.filename.to_s).presence || content_type_extension_for(blob.content_type)
        folder = photo.section.to_s
        entry_name = format("%s/%03d_%s%s", folder, index + 1, folder, extension)

        zip.get_output_stream(entry_name) do |entry|
          blob.open do |source|
            IO.copy_stream(source, entry)
          end
        end
      end
    end

    zip_file.rewind
    zip_file
  end

  def zip_filename_for(attachable:, section:)
    attachable_key = case attachable
    when Container
      "contenedor_#{attachable.number}"
    when BlHouseLine
      "partida_#{attachable.partida}"
    else
      "fotos"
    end

    "#{attachable_key}_#{section}.zip".parameterize(separator: "_")
  end

  def content_type_extension_for(content_type)
    case content_type
    when "image/jpeg", "image/jpg"
      ".jpg"
    when "image/png"
      ".png"
    when "image/webp"
      ".webp"
    when "image/heic"
      ".heic"
    when "image/heif"
      ".heif"
    else
      ".bin"
    end
  end
end
