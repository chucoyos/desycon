class InvoiceEvent < ApplicationRecord
  EVENT_TYPES = %w[
    token_requested
    token_refreshed
    issue_requested
    issue_succeeded
    issue_failed
    cancel_requested
    cancel_succeeded
    cancel_failed
    xml_requested
    xml_stored
    pdf_requested
    pdf_stored
    reconcile_requested
    reconcile_synced
    reconcile_not_found
    reconcile_failed
  ].freeze

  belongs_to :invoice
  belongs_to :created_by, polymorphic: true, optional: true

  validates :event_type, presence: true, inclusion: { in: EVENT_TYPES }
end
