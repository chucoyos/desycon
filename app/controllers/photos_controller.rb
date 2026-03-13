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

  def destroy
    @photo = Photo.find(params[:id])
    authorize @photo

    attachable = @photo.attachable
    @photo.destroy

    redirect_back fallback_location: polymorphic_path(attachable), notice: "Fotografía eliminada correctamente."
  end

  private

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
end
