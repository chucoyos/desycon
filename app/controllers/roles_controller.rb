class RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [ :show, :edit, :update, :destroy, :permissions, :update_permissions ]
  after_action :verify_authorized, except: :index

  def index
    @roles = policy_scope(Role).order(:name).page(params[:page])
    authorize Role
  end

  def show
    authorize @role
  end

  def new
    @role = Role.new
    authorize @role
  end

  def edit
    authorize @role
  end

  def permissions
    authorize @role
    @permissions = Permission.ordered
  end

  def create
    @role = Role.new(role_params)
    authorize @role

    if @role.save
      redirect_to @role, notice: "Role creado exitosamente."
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    authorize @role

    if @role.update(role_params)
      redirect_to @role, notice: "Role actualizado exitosamente."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    authorize @role
    @role.destroy
    redirect_to roles_url, notice: "Role eliminado exitosamente."
  end

  def update_permissions
    authorize @role
    selected_ids = Array(params[:role][:permission_ids]).reject(&:blank?)
    @role.permission_ids = selected_ids
    if @role.save
      redirect_to permissions_role_path(@role), notice: "Permisos actualizados exitosamente."
    else
      @permissions = Permission.ordered
      flash.now[:alert] = "No se pudieron actualizar los permisos."
      render :permissions, status: :unprocessable_content
    end
  end

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name)
  end
end
