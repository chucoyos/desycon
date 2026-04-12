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

    zip_path = build_zip_file(attachable: attachable, photos: photos, section: request.section)

    File.open(zip_path, "rb") do |file|
      request.archive.attach(
        io: file,
        filename: zip_filename_for(attachable: attachable, section: request.section),
        content_type: "application/zip"
      )
    end

    request.mark_completed!(photos_count: photos.size)
  rescue StandardError => e
    request&.mark_failed!(e.message)
    Rails.logger.error("[Photos::BuildArchiveJob] request_id=#{photo_archive_request_id} error=#{e.class}: #{e.message}")
  ensure
    File.delete(zip_path) if defined?(zip_path) && zip_path.present? && File.exist?(zip_path)
  end

  private

  def photos_for_request(request:, attachable:)
    scope = attachable.photos.recent.includes(image_attachment: :blob)
    scope = scope.for_section(request.section) unless request.section == PhotoArchiveRequest::SECTION_ALL

    scope.select { |photo| photo.image.attached? }
  end

  def build_zip_file(attachable:, photos:, section:)
    require "zip"
    require "fileutils"

    export_dir = Rails.root.join("tmp", "photo_exports")
    FileUtils.mkdir_p(export_dir)

    zip_path = export_dir.join("#{attachable.class.name.underscore}_#{attachable.id}_#{section}_#{SecureRandom.hex(8)}.zip")

    Zip::File.open(zip_path, create: true) do |zip|
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

    zip_path.to_s
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
