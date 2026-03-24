class EntitiesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_entity, only: [ :show, :edit, :update, :destroy ]
  before_action :load_patents, only: [ :show ]
  after_action :verify_authorized, except: :index

  def index
    per = params[:per].to_i
    allowed = [ 10, 25, 50, 100 ]
    per = 10 unless allowed.include?(per)
    @per_page = per

    @entities = policy_scope(Entity).includes(:fiscal_profile, :addresses)

    # Aplicar filtros de búsqueda
    @entities = @entities.where("name ILIKE ?", "%#{params[:name]}%") if params[:name].present?
    @entities = @entities.where(role_kind: params[:role]) if params[:role].present?

    @entities = @entities.order(:name).page(params[:page]).per(per)
    authorize Entity
  end

  def show
    @entity.build_fiscal_profile unless @entity.fiscal_profile.present?
    authorize @entity
  end

  def new
    @entity = Entity.new
    @entity.role_kind = "customs_broker" if params[:role] == "customs_broker"
    # Build associated objects for the form
    @entity.build_fiscal_profile
    @entity.addresses.build
    build_email_recipient_if_needed(@entity)
    authorize @entity
  end

  def new_address
    @entity = Entity.new
    authorize @entity
    respond_to do |format|
      format.turbo_stream
    end
  end

  def edit
    # Ensure at least one address field is available for editing
    @entity.addresses.build if @entity.addresses.empty?
    @entity.build_fiscal_profile unless @entity.fiscal_profile.present?
    build_email_recipient_if_needed(@entity)
    authorize @entity
  end

  def create
    @entity = Entity.new(entity_params)

    # Assign customs agent if current user is a customs agent and no customs_agent is already assigned
    if current_user.customs_broker? && current_user.entity&.role_customs_agent? && @entity.customs_agent_id.blank?
      @entity.customs_agent = current_user.entity
      @entity.role_kind = "client"
    end

    authorize @entity

    # Handle duplicate addresses for new entities
    if @entity.new_record? && @entity.addresses.size > 1
      @entity.addresses = [ @entity.addresses.last ]
    end

    if @entity.save
      redirect_to @entity, notice: "Entidad creada exitosamente."
    else
      # Rebuild associated objects for form display when validation fails
      @entity.build_fiscal_profile unless @entity.fiscal_profile
      @entity.addresses.build if @entity.addresses.empty?
      build_email_recipient_if_needed(@entity)
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @entity

    # If no modal context, force HTML path (redirect) even if Turbo Drive is enabled
    modal_context = params[:modal].present?

    respond_to do |format|
      if @entity.update(entity_params)
        @entity.reload # Reload to ensure associations are fresh
        enqueue_customs_agency_access_recalculation(@entity)

        if modal_context
          format.turbo_stream do
            flash.now[:notice] = "Entidad actualizada exitosamente."
            case params[:modal]
            when "address"
              render turbo_stream: [
                turbo_stream.replace("addresses_container", partial: "entities/addresses_section", locals: { entity: @entity }),
                turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
                turbo_stream.replace("address-modal", partial: "entities/address_modal", locals: { entity: @entity })
              ]
            when "patent"
              render turbo_stream: [
                turbo_stream.replace("patents_container", partial: "entities/patents_section", locals: { entity: @entity }),
                turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
                turbo_stream.replace("patent-modal", partial: "entities/patent_modal", locals: { entity: @entity })
              ]
            when "fiscal"
              render turbo_stream: [
                turbo_stream.replace("fiscal_profile_container", partial: "entities/fiscal_profile_section", locals: { entity: @entity }),
                turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
                turbo_stream.replace("fiscal-modal", partial: "entities/fiscal_modal", locals: { entity: @entity })
              ]
            when "roles"
              render turbo_stream: [
                turbo_stream.replace("entity_show", template: "entities/show", locals: { entity: @entity }),
                turbo_stream.replace("flash_messages", partial: "shared/flash_messages", locals: { flash: flash }),
                turbo_stream.replace("roles-modal", partial: "entities/roles_modal", locals: { entity: @entity })
              ]
            else
              render turbo_stream: [
                turbo_stream.replace("entity_show", partial: "entities/show", locals: { entity: @entity }),
                turbo_stream.remove("#{params[:modal]}-modal")
              ]
            end
          end
        end

        format.html do
          redirect_to @entity, notice: "Entidad actualizada exitosamente."
        end
      else
        @entity.build_fiscal_profile unless @entity.fiscal_profile
        @entity.addresses.build if @entity.addresses.empty?
        build_email_recipient_if_needed(@entity)

        if modal_context
          format.turbo_stream do
            render turbo_stream: turbo_stream.replace("#{params[:modal]}_form", partial: "entities/modal_form", locals: { entity: @entity, modal: params[:modal] })
          end
        end

        format.html do
          render :edit, status: :unprocessable_content
        end
      end
    end
  end

  def destroy
    authorize @entity

    if @entity.destroy
      redirect_to entities_path, notice: "Entidad eliminada exitosamente."
    else
      message = @entity.errors.full_messages.to_sentence.presence || "No se pudo eliminar la entidad."
      redirect_to entities_path, alert: message
    end
  rescue ActiveRecord::InvalidForeignKey
    redirect_to entities_path, alert: "No se puede eliminar la entidad porque tiene usuarios asociados."
  end

  private

  def set_entity
    @entity = Entity.includes(:fiscal_profile, :addresses).find(params.expect(:id))
  end

  def load_patents
    # Patents are managed via broker entities now
  end

  def enqueue_customs_agency_access_recalculation(entity)
    return unless entity.role_customs_agent?

    if !entity.enforce_overdue_payment_rule? && entity.restricted_access_enabled?
      entity.set_restricted_access!(enabled: false, reason: nil)
      return
    end

    return unless entity.enforce_overdue_payment_rule?

    CustomsAgents::RecalculateAccessRestrictionsJob.perform_later(customs_agent_id: entity.id)
  end

  def entity_params
    permitted_attributes = [
      :name,
      :requires_bl_endosado_documento,
      :requires_liberacion_documento,
      :requires_encomienda_documento,
      :requires_pago_documento,
      fiscal_profile_attributes: [
        :id, :rfc, :razon_social, :regimen, :uso_cfdi, :forma_pago, :metodo_pago, :_destroy
      ],
      addresses_attributes: [
        :id, :calle, :numero_exterior, :numero_interior, :colonia, :municipio, :localidad,
        :estado, :codigo_postal, :pais, :email, :tipo, :_destroy
      ],
      entity_email_recipients_attributes: [
        :id, :email, :position, :active, :primary_recipient, :_destroy
      ]
    ]

    if current_user.admin_or_executive?
      permitted_attributes += [ :role_kind, :customs_agent_id, :patent_number, :enforce_overdue_payment_rule ]
    end

    params.require(:entity).permit(permitted_attributes)
  end

  def build_email_recipient_if_needed(entity)
    return unless entity.role_customs_agent? || entity.role_consolidator?
    return if entity.entity_email_recipients.reject(&:marked_for_destruction?).any?

    entity.entity_email_recipients.build(active: true, primary_recipient: true, position: 0)
  end
end
