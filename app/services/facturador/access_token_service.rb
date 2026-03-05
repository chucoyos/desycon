module Facturador
  class AccessTokenService
    class << self
      def fetch!
        return TokenStore.valid_access_token if TokenStore.valid_access_token.present?

        refresh_if_possible || authenticate!
      end

      private

      def refresh_if_possible
        refresh_token = TokenStore.refresh_token
        return nil if refresh_token.blank?

        payload = Client.new.refresh_token(refresh_token)
        TokenStore.write!(payload)
        payload["access_token"]
      rescue AuthenticationError, RequestError
        nil
      end

      def authenticate!
        payload = Client.new.token
        TokenStore.write!(payload)
        payload["access_token"]
      end
    end
  end
end
