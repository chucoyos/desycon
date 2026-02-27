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
end
