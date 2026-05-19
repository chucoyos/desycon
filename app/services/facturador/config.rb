module Facturador
  class Config
    class << self
      def enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:enabled, false))
      end

      def environment
        env_value(:environment, "sandbox")
      end

      def auto_issue_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:auto_issue_enabled, false))
      end

      def auto_issue_nipon_exception_enabled?
        ActiveModel::Type::Boolean.new.cast(ENV.fetch("AUTO_ISSUE_NIPON_EXCEPTION_ENABLED", false))
      end

      def auto_issue_nipon_rfc
        ENV.fetch("AUTO_ISSUE_NIPON_RFC", "").to_s.upcase.strip.presence
      end

      def auto_issue_exception_rfcs
        legacy_rfc = auto_issue_nipon_rfc
        configured = ENV.fetch("AUTO_ISSUE_EXCEPTION_RFCS", "")

        rfcs = configured
          .to_s
          .split(/[\s,;]+/)
          .filter_map { |rfc| rfc.to_s.upcase.strip.presence }

        rfcs << legacy_rfc if legacy_rfc.present?
        rfcs.uniq
      end

      def manual_actions_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:manual_actions_enabled, false))
      end

      def reconciliation_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:reconciliation_enabled, false))
      end

      def auto_sync_documents_on_reconcile_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:auto_sync_documents_on_reconcile_enabled, false))
      end

      def external_invoices_sync_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:external_invoices_sync_enabled, false))
      end

      def external_invoices_allowed_environment
        env_value(:external_invoices_allowed_environment, "production").to_s
      end

      def external_invoices_runtime_enabled?
        return false unless enabled?
        return false unless external_invoices_sync_enabled?
        return false unless external_sync_environment_allowed?
        return false if external_sync_stage_endpoint_in_production?

        true
      end

      def external_sync_initial_backfill_days
        value = env_value(:external_sync_initial_backfill_days, 60)
        days = value.to_i
        days.positive? ? days : 60
      end

      def external_sync_window_hours
        value = env_value(:external_sync_window_hours, 24)
        hours = value.to_i
        hours.positive? ? hours : 24
      end

      def external_sync_overlap_minutes
        value = env_value(:external_sync_overlap_minutes, 120)
        minutes = value.to_i
        minutes.positive? ? minutes : 120
      end

      def external_sync_take
        value = env_value(:external_sync_take, 100)
        take = value.to_i
        take.positive? ? [ take, 200 ].min : 100
      end

      def external_sync_max_pages
        value = env_value(:external_sync_max_pages)
        return nil if value.blank?

        pages = value.to_i
        pages.positive? ? pages : nil
      end

      def reconciliation_max_age_days
        value = env_value(:reconciliation_max_age_days, 60)
        days = value.to_i
        days.positive? ? days : nil
      end

      def payment_complements_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:payment_complements_enabled, false))
      end

      def auto_issue_rep_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:auto_issue_rep_enabled, true))
      end

      def email_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:email_enabled, false))
      end

      def issuer_entity_id
        value = env_value(:issuer_entity_id)
        value.present? ? value.to_i : nil
      end

      def issuer_entity
        return nil if issuer_entity_id.blank?

        Entity.find_by(id: issuer_entity_id)
      end

      def auth_base_url
        env_value(:auth_base_url, "https://authcli.stagefacturador.com")
      end

      def business_base_url
        env_value(:business_base_url, "https://pruebas.stagefacturador.com")
      end

      def serie
        env_value(:serie).presence
      end

      def payment_serie
        env_value(:payment_serie).presence
      end

      def serie_id
        normalized_serie_id(env_value(:serie_id))
      end

      def payment_serie_id
        normalized_serie_id(env_value(:payment_serie_id))
      end

      def username
        env_value(:username)
      end

      def password_md5
        env_value(:password_md5)
      end

      def client_id
        env_value(:client_id)
      end

      def client_secret
        env_value(:client_secret)
      end

      def email_subject
        env_value(:email_subject, "Tu comprobante Fiscal Digital con la nueva versión 3.3")
      end

      def email_message
        env_value(:email_message, "hola")
      end

      def credentials_present?
        username.present? && password_md5.present? && client_id.present? && client_secret.present?
      end

      def validate!
        return true unless enabled?

        raise ConfigurationError, "Facturador credentials are missing" unless credentials_present?

        true
      end

      private

      def external_sync_environment_allowed?
        allowed = external_invoices_allowed_environment.to_s.strip
        return Rails.env.production? if allowed.blank?

        Rails.env.to_s == allowed
      end

      def external_sync_stage_endpoint_in_production?
        return false unless Rails.env.production?

        business_base_url.to_s.downcase.include?("stagefacturador")
      end

      def normalized_serie_id(value)
        raw = value.to_s.strip
        return nil if raw.blank?

        parsed = raw.to_i
        parsed.positive? ? parsed : nil
      end

      def env_value(key, fallback = nil)
        env_key = "FACTURADOR_#{key.to_s.upcase}"
        ENV.fetch(env_key) do
          Rails.application.credentials.dig(:facturador, key) || fallback
        end
      end
    end
  end
end
