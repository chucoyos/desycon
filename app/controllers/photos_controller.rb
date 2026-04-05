class PhotosController < ApplicationController
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

    send_data build_photos_zip(attachable: attachable, section: section, photos: photos),
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

    send_data build_photos_zip(attachable: attachable, photos: photos),
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

  def build_photos_zip(attachable:, photos:, section: nil)
    require "zip"

    Zip::OutputStream.write_buffer do |zip|
      photos.each_with_index do |photo, index|
        blob = photo.image.blob
        extension = File.extname(blob.filename.to_s).presence || content_type_extension_for(blob.content_type)
        photo_section = section.presence || photo.section.to_s
        entry_name = if section.present?
          format("%03d_%s%s", index + 1, section, extension)
        else
          format("%s/%03d_%s%s", photo_section, index + 1, photo_section, extension)
        end

        zip.put_next_entry(entry_name)
        zip.write(blob.download)
      end
    end.string
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
