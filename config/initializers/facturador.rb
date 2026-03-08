Rails.application.config.x.facturador = ActiveSupport::OrderedOptions.new
facturador_credentials = Rails.application.credentials.dig(:facturador) || {}

Rails.application.config.x.facturador.enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("FACTURADOR_ENABLED", facturador_credentials[:enabled] || false)
)
Rails.application.config.x.facturador.environment = ENV.fetch(
  "FACTURADOR_ENVIRONMENT",
  facturador_credentials[:environment] || "sandbox"
)
Rails.application.config.x.facturador.auto_issue_enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("FACTURADOR_AUTO_ISSUE_ENABLED", facturador_credentials[:auto_issue_enabled] || false)
)
Rails.application.config.x.facturador.manual_actions_enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("FACTURADOR_MANUAL_ACTIONS_ENABLED", facturador_credentials[:manual_actions_enabled] || false)
)
Rails.application.config.x.facturador.reconciliation_enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("FACTURADOR_RECONCILIATION_ENABLED", facturador_credentials[:reconciliation_enabled] || false)
)
Rails.application.config.x.facturador.payment_complements_enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("FACTURADOR_PAYMENT_COMPLEMENTS_ENABLED", facturador_credentials[:payment_complements_enabled] || false)
)
Rails.application.config.x.facturador.email_enabled = ActiveModel::Type::Boolean.new.cast(
  ENV.fetch("FACTURADOR_EMAIL_ENABLED", facturador_credentials[:email_enabled] || false)
)
issuer_entity_id = facturador_credentials[:issuer_entity_id]
Rails.application.config.x.facturador.issuer_entity_id = ENV.fetch("FACTURADOR_ISSUER_ENTITY_ID", issuer_entity_id).presence
Rails.application.config.x.facturador.auth_base_url = ENV.fetch(
  "FACTURADOR_AUTH_BASE_URL",
  facturador_credentials[:auth_base_url] || "https://authcli.stagefacturador.com"
)
Rails.application.config.x.facturador.business_base_url = ENV.fetch(
  "FACTURADOR_BUSINESS_BASE_URL",
  facturador_credentials[:business_base_url] || "https://pruebas.stagefacturador.com"
)
Rails.application.config.x.facturador.email_subject = ENV.fetch(
  "FACTURADOR_EMAIL_SUBJECT",
  facturador_credentials[:email_subject] || "Tu comprobante Fiscal Digital con la nueva versión 3.3"
)
Rails.application.config.x.facturador.email_message = ENV.fetch(
  "FACTURADOR_EMAIL_MESSAGE",
  facturador_credentials[:email_message] || "hola"
)
