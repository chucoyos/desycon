module Admin
  class UsersController < ApplicationController
    before_action :authenticate_user!
    before_action :set_user, only: [ :show, :edit, :update, :destroy ]
    after_action :verify_authorized, except: :index

    def index
      @roles = Role.order(:name)

      @users = policy_scope(User).includes(:role, :entity)

      if params[:search].present?
        @users = @users.where("users.email ILIKE ?", "%#{params[:search]}%")
      end

      if params[:role_id].present?
        @users = @users.where(role_id: params[:role_id])
      end

      case params[:disabled]
      when "enabled"
        @users = @users.where(disabled: false)
      when "disabled"
        @users = @users.where(disabled: true)
      end

      @users = @users.order(:email).page(params[:page])
      authorize User
    end

    def show
      authorize @user
    end

    def new
      @user = User.new
      authorize @user
    end

    def edit
      authorize @user
    end

    def create
      @user = User.new(user_params)
      authorize @user

      if @user.save
        redirect_to admin_user_path(@user), notice: "Usuario creado exitosamente."
      else
        render :new, status: :unprocessable_content
      end
    end

    def update
      authorize @user

      if @user.update(user_params)
        redirect_to admin_user_path(@user), notice: "Usuario actualizado exitosamente."
      else
        render :edit, status: :unprocessable_content
      end
    end

    def destroy
      authorize @user
      @user.destroy
      redirect_to admin_users_url, notice: "Usuario eliminado exitosamente."
    end

    private

    def set_user
      @user = User.find(params[:id])
    end

    def user_params
      params.require(:user).permit(:email, :password, :password_confirmation, :role_id, :entity_id, :disabled)
    end
  end
end
