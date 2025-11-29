class ConsolidatorsController < ApplicationController
  before_action :set_consolidator, only: %i[show edit update destroy]

  def index
    @consolidators = policy_scope(Consolidator)
                       .with_fiscal_data
                       .alphabetical
                       .page(params[:page])
                       .per(per)
    authorize Consolidator
  end

  def show
    authorize @consolidator
  end

  def new
    @consolidator = Consolidator.new
    authorize @consolidator
    @consolidator.build_fiscal_profile_if_needed
    @consolidator.build_fiscal_address_if_needed
  end

  def edit
    authorize @consolidator
    @consolidator.build_fiscal_profile_if_needed
    @consolidator.build_fiscal_address_if_needed
  end

  def create
    @consolidator = Consolidator.new(consolidator_params)
    authorize @consolidator

    if @consolidator.save
      redirect_to @consolidator, notice: 'Consolidador creado exitosamente.'
    else
      render :new, status: :unprocessable_entity
    end
  end

  def update
    authorize @consolidator

    if @consolidator.update(consolidator_params)
      redirect_to @consolidator, notice: 'Consolidador actualizado exitosamente.'
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    authorize @consolidator
    @consolidator.destroy!
    redirect_to consolidators_url, notice: 'Consolidador eliminado exitosamente.'
  end

  private

  def set_consolidator
    @consolidator = Consolidator.includes(:fiscal_profile, :addresses).find(params[:id])
  end

  def consolidator_params
    params.require(:consolidator).permit(
      :name,
      fiscal_profile_attributes: [
        :id, :razon_social, :rfc, :regimen, :uso_cfdi, :forma_pago, :metodo_pago, :_destroy
      ],
      addresses_attributes: [
        :id, :tipo, :pais, :codigo_postal, :estado, :municipio, :localidad,
        :colonia, :calle, :numero_exterior, :numero_interior, :email, :_destroy
      ]
    )
  end

  def per
    params[:per]&.to_i&.clamp(10, 100) || 25
  end
end
