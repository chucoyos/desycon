module Facturador
  class EmisorService
    CACHE_KEY = "facturador/emisor_id".freeze

    class << self
      def emisor_id!(access_token:)
        cached = Rails.cache.read(CACHE_KEY)
        return cached if cached.present?

        payload = Client.new(access_token: access_token).user_info
        emisor_id = payload["emisorid"]
        raise RequestError, "Facturador emisorid missing" if emisor_id.blank?

        Rails.cache.write(CACHE_KEY, emisor_id, expires_in: 12.hours)
        emisor_id
      end

      def clear!
        Rails.cache.delete(CACHE_KEY)
      end
    end
  end
end
