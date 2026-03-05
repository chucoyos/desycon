class InvoicesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice, only: %i[cancel sync_documents register_payment]
  after_action :verify_authorized

  def index
    authorize Invoice

    @selected_start_date = resolved_start_date
    @selected_end_date = resolved_end_date
    @selected_status = params[:status].to_s.presence
    @selected_client_id = params[:client_id].to_s.presence
    @selected_uuid = params[:uuid].to_s.strip.presence

    start_date = [ @selected_start_date, @selected_end_date ].min
    end_date = [ @selected_start_date, @selected_end_date ].max

    @invoices = policy_scope(Invoice)
                .includes(:receiver_entity)
                .where(created_at: start_date.beginning_of_day..end_date.end_of_day)
                .order(created_at: :desc)

    @invoices = @invoices.where(status: @selected_status) if @selected_status.present? && Invoice::STATUSES.include?(@selected_status)
    @invoices = @invoices.where(receiver_entity_id: @selected_client_id) if @selected_client_id.present?
    @invoices = @invoices.where("sat_uuid ILIKE ?", "%#{@selected_uuid}%") if @selected_uuid.present?

    @invoices = @invoices.page(params[:page]).per(params[:per] || 25)

    @invoice_statuses = Invoice::STATUSES
    @clients = Entity.clients.order(:name)
  end

  def issue_manual
    authorize Invoice, :issue_manual?

    invoiceable = find_invoiceable
    unless invoiceable
      return redirect_back fallback_location: containers_path, alert: "Servicio no encontrado."
    end

    invoice = Facturador::ManualIssueService.call(invoiceable: invoiceable, actor: current_user)

    if invoice.present?
      redirect_back fallback_location: containers_path, notice: "Emisión manual encolada/ejecutada correctamente."
    else
      redirect_back fallback_location: containers_path, alert: "No fue posible encolar la emisión manual. Revisa configuración y perfiles fiscales."
    end
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al emitir CFDI: #{e.message}"
  end

  def cancel
    authorize @invoice, :cancel?

    Facturador::CancelInvoiceService.call(
      invoice: @invoice,
      motive: "02",
      replacement_uuid: nil,
      actor: current_user
    )

    redirect_back fallback_location: containers_path, notice: "Cancelación solicitada/procesada correctamente."
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al cancelar CFDI: #{e.message}"
  end

  def sync_documents
    authorize @invoice, :sync_documents?

    Facturador::SyncInvoiceDocumentsService.call(invoice: @invoice, actor: current_user)
    redirect_back fallback_location: containers_path, notice: "XML y PDF sincronizados correctamente."
  rescue Facturador::Error => e
    redirect_back fallback_location: containers_path, alert: "Error al sincronizar documentos: #{e.message}"
  end

  def register_payment
    authorize @invoice, :register_payment?

    payment = Facturador::RegisterInvoicePaymentService.call(
      invoice: @invoice,
      amount: payment_params[:amount],
      paid_at: payment_params[:paid_at],
      payment_method: payment_params[:payment_method],
      reference: payment_params[:reference],
      notes: payment_params[:notes],
      actor: current_user
    )

    if payment.complement_invoice_id.present?
      redirect_back fallback_location: containers_path, notice: "Pago registrado y complemento de pago encolado."
    else
      redirect_back fallback_location: containers_path, notice: "Pago registrado correctamente."
    end
  rescue Facturador::Error, ActiveRecord::RecordInvalid => e
    redirect_back fallback_location: containers_path, alert: "Error al registrar pago: #{e.message}"
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:id])
  end

  def find_invoiceable
    type = params[:invoiceable_type].to_s
    id = params[:invoiceable_id]

    return nil if id.blank?

    case type
    when "ContainerService"
      ContainerService.find_by(id: id)
    when "BlHouseLineService"
      BlHouseLineService.find_by(id: id)
    else
      nil
    end
  end

  def payment_params
    params.require(:payment).permit(:amount, :paid_at, :payment_method, :reference, :notes)
  end

  def resolved_start_date
    parse_filter_date(params[:start_date]) || default_start_date
  end

  def resolved_end_date
    parse_filter_date(params[:end_date]) || default_end_date
  end

  def parse_filter_date(value)
    return nil if value.blank?

    Date.iso8601(value)
  rescue ArgumentError
    nil
  end

  def default_start_date
    Date.current - 60.days
  end

  def default_end_date
    Date.current
  end
end
