class RolesController < ApplicationController
  before_action :authenticate_user!
  before_action :set_role, only: [ :show, :edit, :update, :destroy ]
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

  private

  def set_role
    @role = Role.find(params[:id])
  end

  def role_params
    params.require(:role).permit(:name)
  end
end
