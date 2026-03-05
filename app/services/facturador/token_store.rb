module Facturador
  class TokenStore
    CACHE_KEY = "facturador/token".freeze
    EXPIRY_SKEW_SECONDS = 60

    class << self
      def read
        Rails.cache.read(CACHE_KEY) || {}
      end

      def write!(payload)
        expires_in = payload.fetch("expires_in", 0).to_i
        expires_at = Time.current + expires_in.seconds

        data = {
          access_token: payload["access_token"],
          refresh_token: payload["refresh_token"],
          expires_at: expires_at,
          token_type: payload["token_type"]
        }

        ttl = [ expires_in - EXPIRY_SKEW_SECONDS, 60 ].max
        Rails.cache.write(CACHE_KEY, data, expires_in: ttl)
        data
      end

      def clear!
        Rails.cache.delete(CACHE_KEY)
      end

      def valid_access_token
        data = read
        return nil if data[:access_token].blank?
        return nil if data[:expires_at].blank?
        return nil if data[:expires_at] <= Time.current + EXPIRY_SKEW_SECONDS.seconds

        data[:access_token]
      end

      def refresh_token
        read[:refresh_token]
      end
    end
  end
end
