class PhotosController < ApplicationController
  PHOTO_EXPORT_RETENTION = 2.hours

  before_action :authenticate_user!
  after_action :verify_authorized

  def create_for_container
    attachable = Container.find(params[:id])
    create_for_attachable(attachable)
  end

  def create_for_bl_house_line
    attachable = BlHouseLine.find(params[:id])
    create_for_attachable(attachable)
  end

  def destroy_section_for_container
    attachable = Container.find(params[:id])
    destroy_section_for_attachable(attachable)
  end

  def destroy_section_for_bl_house_line
    attachable = BlHouseLine.find(params[:id])
    destroy_section_for_attachable(attachable)
  end

  def download_section_for_container
    attachable = Container.find(params[:id])
    download_section_for_attachable(attachable)
  end

  def download_section_for_bl_house_line
    attachable = BlHouseLine.find(params[:id])
    download_section_for_attachable(attachable)
  end

  def download_all_for_container
    attachable = Container.find(params[:id])
    download_all_for_attachable(attachable)
  end

  def download_all_for_bl_house_line
    attachable = BlHouseLine.find(params[:id])
    download_all_for_attachable(attachable)
  end

  def destroy
    @photo = Photo.find(params[:id])
    authorize @photo

    attachable = @photo.attachable
    @photo.destroy

    redirect_back fallback_location: polymorphic_path(attachable), notice: "Fotografía eliminada correctamente."
  end

  private

  def download_section_for_attachable(attachable)
    authorize attachable, :show?
    authorize Photo, :download?

    section = params[:section].to_s
    allowed_sections = Photo.allowed_sections_for(attachable)

    unless allowed_sections.include?(section)
      return redirect_back fallback_location: polymorphic_path(attachable), alert: "Sección inválida para descargar fotografías."
    end

    photos = attachable.photos.for_section(section).recent.includes(image_attachment: :blob)
    photos = photos.select { |photo| photo.image.attached? }

    if photos.empty?
      return redirect_back fallback_location: polymorphic_path(attachable), alert: "No hay fotografías para descargar en esta sección."
    end

    zip_path = build_photos_zip_file(attachable: attachable, section: section, photos: photos)

    send_file zip_path,
          filename: zip_filename_for(attachable: attachable, section: section),
          type: "application/zip",
          disposition: "attachment"
  end

  def download_all_for_attachable(attachable)
    authorize attachable, :show?
    authorize Photo, :download?

    photos = attachable.photos.recent.includes(image_attachment: :blob)
    photos = photos.select { |photo| photo.image.attached? }

    if photos.empty?
      return redirect_back fallback_location: polymorphic_path(attachable), alert: "No hay fotografías para descargar."
    end

    zip_path = build_photos_zip_file(attachable: attachable, photos: photos)

    send_file zip_path,
          filename: zip_filename_for(attachable: attachable, section: "todas_las_secciones"),
          type: "application/zip",
          disposition: "attachment"
  end

  def create_for_attachable(attachable)
    authorize Photo, :create?

    permitted = photo_params
    images = Array(permitted[:images]).reject(&:blank?)

    if images.empty?
      return redirect_back fallback_location: polymorphic_path(attachable), alert: "Selecciona al menos una fotografía."
    end

    section = permitted[:section]
    saved_count = 0
    last_error = nil

    ActiveRecord::Base.transaction do
      images.each do |image|
        photo = attachable.photos.build(section: section, uploaded_by: current_user)
        photo.image.attach(image)

        if photo.save
          saved_count += 1
          Photos::PreprocessVariantJob.perform_later(photo.id)
        else
          last_error = photo.errors.full_messages.to_sentence
          raise ActiveRecord::Rollback
        end
      end
    end

    if last_error.present?
      redirect_back fallback_location: polymorphic_path(attachable), alert: "No se pudieron guardar las fotografías: #{last_error}"
    else
      redirect_back fallback_location: polymorphic_path(attachable), notice: "#{saved_count} fotografía(s) cargada(s) correctamente."
    end
  end

  def photo_params
    params.require(:photo).permit(:section, images: [])
  end

  def destroy_section_for_attachable(attachable)
    authorize Photo, :destroy?

    section = params.dig(:photo, :section).to_s
    allowed_sections = Photo.allowed_sections_for(attachable)

    unless allowed_sections.include?(section)
      return redirect_back fallback_location: polymorphic_path(attachable), alert: "Sección inválida para eliminar fotografías."
    end

    photos = attachable.photos.for_section(section)
    deleted_count = photos.count

    if deleted_count.zero?
      return redirect_back fallback_location: polymorphic_path(attachable), alert: "No hay fotografías para eliminar en esta sección."
    end

    photos.destroy_all

    redirect_back fallback_location: polymorphic_path(attachable), notice: "#{deleted_count} fotografía(s) eliminada(s) de la sección."
  end

  def build_photos_zip_file(attachable:, photos:, section: nil)
    require "zip"
    require "fileutils"

    cleanup_old_photo_exports!
    export_dir = Rails.root.join("tmp", "photo_exports")
    FileUtils.mkdir_p(export_dir)
    zip_path = export_dir.join("#{attachable.class.name.underscore}_#{attachable.id}_#{SecureRandom.hex(8)}.zip")

    Zip::File.open(zip_path, create: true) do |zip|
      photos.each_with_index do |photo, index|
        blob = photo.image.blob
        extension = File.extname(blob.filename.to_s).presence || content_type_extension_for(blob.content_type)
        photo_section = section.presence || photo.section.to_s
        entry_name = if section.present?
          format("%03d_%s%s", index + 1, section, extension)
        else
          format("%s/%03d_%s%s", photo_section, index + 1, photo_section, extension)
        end

        zip.get_output_stream(entry_name) do |entry|
          blob.open do |source|
            IO.copy_stream(source, entry)
          end
        end
      end
    end

    zip_path.to_s
  end

  def cleanup_old_photo_exports!
    export_dir = Rails.root.join("tmp", "photo_exports")
    return unless Dir.exist?(export_dir)

    cutoff_time = Time.current - PHOTO_EXPORT_RETENTION
    Dir.glob(export_dir.join("*.zip")).each do |file_path|
      File.delete(file_path) if File.mtime(file_path) < cutoff_time
    rescue StandardError
      nil
    end
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
