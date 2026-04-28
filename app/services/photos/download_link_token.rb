module Photos
  class DownloadLinkToken
    PURPOSE = "photo_download_link".freeze

    class << self
      def issue(link:)
        verifier.generate(payload_for(link))
      end

      def resolve(token:, allow_expired: false)
        payload = verifier.verify(token)
        link_id = payload["id"] || payload[:id]
        payload_exp = (payload["exp"] || payload[:exp]).to_i

        link = PhotoDownloadLink.find_by(id: link_id)
        return nil if link.blank?
        return nil if payload_exp <= 0
        return nil if link.expires_at.to_i != payload_exp
        return nil if !allow_expired && payload_exp <= Time.current.to_i

        link
      rescue ActiveSupport::MessageVerifier::InvalidSignature
        nil
      end

      private

      def payload_for(link)
        {
          id: link.id,
          exp: link.expires_at.to_i
        }
      end

      def verifier
        Rails.application.message_verifier(PURPOSE)
      end
    end
  end
end
