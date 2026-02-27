class Photo < ApplicationRecord
  MAX_IMAGE_SIZE = 15.megabytes
  IMAGE_CONTENT_TYPES = %w[image/jpeg image/jpg image/png image/webp image/heic image/heif].freeze

  ATTACHABLE_SECTIONS = {
    "Container" => %w[apertura desconsolidacion vacio],
    "BlHouseLine" => %w[etiquetado]
  }.freeze

  enum :section, {
    apertura: "apertura",
    desconsolidacion: "desconsolidacion",
    vacio: "vacio",
    etiquetado: "etiquetado"
  }

  belongs_to :attachable, polymorphic: true
  belongs_to :uploaded_by, class_name: "User", optional: true

  has_one_attached :image

  validates :section, presence: true, inclusion: { in: sections.keys }
  validates :position, numericality: { only_integer: true, greater_than_or_equal_to: 0 }

  validate :section_allowed_for_attachable
  validate :image_must_be_attached
  validate :image_must_be_supported_type
  validate :image_size_within_limit

  scope :recent, -> { order(created_at: :desc) }
  scope :for_section, ->(value) { where(section: value) }

  def self.allowed_sections_for(attachable)
    ATTACHABLE_SECTIONS.fetch(attachable.class.name, [])
  end

  def section_label
    case section
    when "apertura"
      "Apertura"
    when "desconsolidacion"
      "Desconsolidación"
    when "vacio"
      "Vacío"
    when "etiquetado"
      "Etiquetado"
    else
      section.to_s.humanize
    end
  end

  private

  def section_allowed_for_attachable
    return if attachable.blank? || section.blank?

    allowed_sections = self.class.allowed_sections_for(attachable)
    return if allowed_sections.include?(section)

    errors.add(:section, "no es válida para este registro")
  end

  def image_must_be_attached
    errors.add(:image, "debe adjuntarse") unless image.attached?
  end

  def image_must_be_supported_type
    return unless image.attached?
    return if IMAGE_CONTENT_TYPES.include?(image.blob.content_type)

    errors.add(:image, "debe ser una imagen válida (JPG, PNG, WEBP o HEIC)")
  end

  def image_size_within_limit
    return unless image.attached?
    return if image.blob.byte_size <= MAX_IMAGE_SIZE

    errors.add(:image, "excede el límite de #{MAX_IMAGE_SIZE / 1.megabyte}MB")
  end
end
