class Photos::BuildArchiveJob < ApplicationJob
  # Reuse the Active Storage worker pool so staging works even when default queue workers are not scaled.
  queue_as :active_storage

  discard_on ActiveJob::DeserializationError

  def perform(photo_archive_request_id)
    started_at = Process.clock_gettime(Process::CLOCK_MONOTONIC)

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
    log_archive_timing(
      request: request,
      status: "ok",
      photos_count: photos.size,
      started_at: started_at
    )
  rescue StandardError => e
    request&.mark_failed!(e.message)
    log_archive_timing(
      request: request,
      status: "error",
      photos_count: 0,
      started_at: started_at,
      error: "#{e.class}: #{e.message}",
      fallback_request_id: photo_archive_request_id
    )
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

  def log_archive_timing(request:, status:, photos_count:, started_at:, error: nil, fallback_request_id: nil)
    return unless photo_timing_logs_enabled?

    duration_ms = ((Process.clock_gettime(Process::CLOCK_MONOTONIC) - started_at) * 1000).round

    Rails.logger.info(
      "[Photos::BuildArchiveJob] status=#{status} request_id=#{request&.id || fallback_request_id} " \
      "attachable_type=#{request&.attachable_type} attachable_id=#{request&.attachable_id} " \
      "section=#{request&.section} photos_count=#{photos_count} duration_ms=#{duration_ms} error=#{error}"
    )
  end

  def photo_timing_logs_enabled?
    ActiveModel::Type::Boolean.new.cast(ENV["PHOTO_TIMING_LOGS"])
  end
end
