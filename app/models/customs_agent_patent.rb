class CustomsAgentPatent < ApplicationRecord
  belongs_to :entity

  validates :patent_number, presence: true,
            uniqueness: { scope: :entity_id, message: "ya existe para esta entidad" }

  def display_name
    patent_number
  end
end
