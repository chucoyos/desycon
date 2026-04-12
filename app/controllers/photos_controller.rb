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

  def section_frame_for_container
    attachable = Container.find(params[:id])
    section_frame_for_attachable(attachable)
  end

  def section_frame_for_bl_house_line
    attachable = BlHouseLine.find(params[:id])
    section_frame_for_attachable(attachable)
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

  def section_frame_for_attachable(attachable)
    authorize attachable, :show?

    section = params[:section].to_s
    allowed_sections = Photo.allowed_sections_for(attachable)
    return head :bad_request unless allowed_sections.include?(section)

    render_section_frame(
      attachable: attachable,
      section: section,
      title: params[:title].to_s,
      subtitle: params[:subtitle].to_s
    )
  end

  def download_section_for_attachable(attachable)
    authorize attachable, :show?
    authorize Photo, :download?

    section = sanitized_download_section_for(attachable)

    if section.blank?
      if request.format.json?
        return render json: { status: "invalid", message: "Sección inválida para descargar fotografías." }, status: :unprocessable_entity
      end

      return redirect_back fallback_location: polymorphic_path(attachable), alert: "Sección inválida para descargar fotografías."
    end

    download_request = latest_download_request_for(attachable: attachable, section: section)

    if download_request&.completed? && download_request.archive.attached? && !download_request.expired?
      return respond_download_ready(download_request)
    end

    if download_request&.in_progress?
      if download_request.stale_in_progress?
        download_request.mark_failed!("La solicitud anterior no termino a tiempo. Se iniciara una nueva generacion.")
      elsif request.format.json?
        return render json: { status: download_request.status, message: "La descarga se esta preparando." }, status: :ok
      else
        return redirect_back fallback_location: polymorphic_path(attachable), notice: "La descarga se esta preparando."
      end
    end

    download_request = enqueue_download_request!(attachable: attachable, section: section)
    Photos::BuildArchiveJob.perform_later(download_request.id)

    if request.format.json?
      return render json: { status: download_request.status, message: "Estamos preparando tu archivo ZIP." }, status: :accepted
    end

    redirect_back fallback_location: polymorphic_path(attachable), notice: "Estamos preparando tu archivo ZIP."
  end

  def download_all_for_attachable(attachable)
    authorize attachable, :show?
    authorize Photo, :download?

    section = PhotoArchiveRequest::SECTION_ALL
    download_request = latest_download_request_for(attachable: attachable, section: section)

    if download_request&.completed? && download_request.archive.attached? && !download_request.expired?
      return respond_download_ready(download_request)
    end

    if download_request&.in_progress?
      if download_request.stale_in_progress?
        download_request.mark_failed!("La solicitud anterior no termino a tiempo. Se iniciara una nueva generacion.")
      elsif request.format.json?
        return render json: { status: download_request.status, message: "La descarga se esta preparando." }, status: :ok
      else
        return redirect_back fallback_location: polymorphic_path(attachable), notice: "La descarga se esta preparando."
      end
    end

    download_request = enqueue_download_request!(attachable: attachable, section: section)
    Photos::BuildArchiveJob.perform_later(download_request.id)

    if request.format.json?
      return render json: { status: download_request.status, message: "Estamos preparando tu archivo ZIP." }, status: :accepted
    end

    redirect_back fallback_location: polymorphic_path(attachable), notice: "Estamos preparando tu archivo ZIP."
  end

  def create_for_attachable(attachable)
    authorize Photo, :create?

    permitted = photo_params
    images = Array(permitted[:images]).reject(&:blank?)
    section = permitted[:section].to_s
    title = params[:title].to_s
    subtitle = params[:subtitle].to_s

    if images.empty?
      if turbo_frame_request?
        return render_section_frame(
          attachable: attachable,
          section: section,
          title: title,
          subtitle: subtitle,
          status: :unprocessable_entity
        )
      end

      return redirect_back fallback_location: polymorphic_path(attachable), alert: "Selecciona al menos una fotografía."
    end

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

    if turbo_frame_request?
      return render_section_frame(
        attachable: attachable,
        section: section,
        title: title,
        subtitle: subtitle,
        status: last_error.present? ? :unprocessable_entity : :ok
      )
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
    purge_archive_requests_for!(attachable: attachable, section: section)

    if turbo_frame_request?
      return render_section_frame(
        attachable: attachable,
        section: section,
        title: params[:title].to_s,
        subtitle: params[:subtitle].to_s
      )
    end

    redirect_back fallback_location: polymorphic_path(attachable), notice: "#{deleted_count} fotografía(s) eliminada(s) de la sección."
  end

  def latest_download_request_for(attachable:, section:)
    PhotoArchiveRequest
      .where(attachable: attachable, requested_by: current_user, section: section)
      .recent_first
      .first
  end

  def enqueue_download_request!(attachable:, section:)
    PhotoArchiveRequest.create!(
      attachable: attachable,
      requested_by: current_user,
      section: section,
      status: :pending
    )
  end

  def purge_archive_requests_for!(attachable:, section:)
    requests = PhotoArchiveRequest.where(attachable: attachable, section: section)

    requests.find_each do |download_request|
      download_request.archive.purge_later if download_request.archive.attached?
      download_request.destroy!
    end
  end

  def respond_download_ready(download_request)
    download_url = rails_blob_path(download_request.archive, disposition: "attachment")

    if request.format.json?
      render json: {
        status: download_request.status,
        message: "ZIP listo para descargar.",
        download_url: download_url
      }, status: :ok
    else
      redirect_to download_url
    end
  end

  def sanitized_download_section_for(attachable)
    raw_section = params[:section].to_s
    literal_section = case raw_section
    when "apertura" then "apertura"
    when "desconsolidacion" then "desconsolidacion"
    when "vacio" then "vacio"
    when "etiquetado" then "etiquetado"
    else
      nil
    end

    allowed_sections = Photo.allowed_sections_for(attachable)
    return nil unless literal_section && allowed_sections.include?(literal_section)

    literal_section
  end

  def render_section_frame(attachable:, section:, title:, subtitle:, status: :ok)
    frame_id = ActionView::RecordIdentifier.dom_id(attachable, "photo_module_#{section}")

    render partial: "shared/photo_module_frame",
      status: status,
      locals: {
        frame_id: frame_id,
        attachable: attachable,
        section: section,
        title: title,
        subtitle: subtitle
      }
  end
end
