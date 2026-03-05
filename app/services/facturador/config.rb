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

      def manual_actions_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:manual_actions_enabled, false))
      end

      def reconciliation_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:reconciliation_enabled, false))
      end

      def payment_complements_enabled?
        ActiveModel::Type::Boolean.new.cast(env_value(:payment_complements_enabled, false))
      end

      def issuer_entity_id
        value = env_value(:issuer_entity_id)
        value.present? ? value.to_i : nil
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

      def credentials_present?
        username.present? && password_md5.present? && client_id.present? && client_secret.present?
      end

      def validate!
        return true unless enabled?

        raise ConfigurationError, "Facturador credentials are missing" unless credentials_present?

        true
      end

      private

      def env_value(key, fallback = nil)
        env_key = "FACTURADOR_#{key.to_s.upcase}"
        ENV.fetch(env_key) do
          Rails.application.credentials.dig(:facturador, key) || fallback
        end
      end
    end
  end
end
