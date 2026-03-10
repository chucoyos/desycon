class InvoicePaymentsController < ApplicationController
  before_action :authenticate_user!
  before_action :set_invoice
  before_action :set_payment
  before_action :ensure_manageable_payment!, only: %i[edit update destroy]
  after_action :verify_authorized

  def show
    authorize @payment

    @payment_evidences = @payment.invoice_payment_evidences
      .includes(:submitted_by, :customs_agent, :receipt_file_attachment)
      .order(created_at: :desc)
  end

  def edit
    authorize @payment, :update?
  end

  def update
    authorize @payment, :update?

    if @payment.update(payment_params)
      redirect_to invoice_path(@invoice, anchor: "payments-section"), notice: "Pago actualizado correctamente."
    else
      flash.now[:alert] = "No fue posible actualizar el pago."
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @payment, :destroy?

    @payment.destroy!
    redirect_to invoice_path(@invoice, anchor: "payments-section"), notice: "Pago eliminado correctamente."
  end

  private

  def set_invoice
    @invoice = Invoice.find(params[:invoice_id])
  end

  def set_payment
    @payment = @invoice.invoice_payments.find(params[:id])
  end

  def payment_params
    params.require(:invoice_payment).permit(:amount, :paid_at, :payment_method, :reference, :tracking_key, :notes, :receipt_file)
  end

  def ensure_manageable_payment!
    return if @payment.complement_invoice_id.blank? && @payment.status.in?([ "registered", "failed" ])

    redirect_to invoice_path(@invoice, anchor: "payments-section"), alert: "Este pago ya está ligado a un complemento y no se puede modificar." and return
  end
end
