class Photos::PreprocessVariantJob < ApplicationJob
  queue_as :active_storage
  GALLERY_VARIANT_TRANSFORMATIONS = { resize_to_limit: [ 420, 420 ], format: :jpeg }.freeze

  discard_on ActiveJob::DeserializationError

  def perform(photo_id)
    photo = Photo.find_by(id: photo_id)
    return unless photo&.image&.attached?
    return unless photo.image.variable?

    # Pre-generate gallery variant to speed up first render in photo sections.
    photo.image.variant(GALLERY_VARIANT_TRANSFORMATIONS).processed
  end
end
