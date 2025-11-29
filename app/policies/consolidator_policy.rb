class ConsolidatorPolicy < ApplicationPolicy
  def index?
    true # Todos pueden ver la lista
  end

  def show?
    true # Todos pueden ver detalles
  end

  def create?
    user.present? # Solo usuarios autenticados pueden crear
  end

  def update?
    user.present? # Solo usuarios autenticados pueden editar
  end

  def destroy?
    user.present? # Solo usuarios autenticados pueden eliminar
  end

  class Scope < Scope
    def resolve
      scope.all
    end
  end
end
