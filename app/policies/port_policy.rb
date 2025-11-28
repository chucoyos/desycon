class PortPolicy < ApplicationPolicy
  # Solo usuarios internos pueden ver el índice
  def index?
    user.internal?
  end

  # Solo usuarios internos pueden ver detalles
  def show?
    user.internal?
  end

  # Solo usuarios internos pueden crear
  def create?
    user.internal?
  end

  # Solo admin y operator pueden editar
  def update?
    user.internal?
  end

  # Solo admin puede eliminar
  def destroy?
    user.admin?
  end

  # Alias para new y edit
  def new?
    create?
  end

  def edit?
    update?
  end

  class Scope < ApplicationPolicy::Scope
    def resolve
      if user.internal?
        scope.all
      else
        scope.none
      end
    end
  end
end
