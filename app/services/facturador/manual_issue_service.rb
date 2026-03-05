module Facturador
  class ManualIssueService
    class << self
      def call(invoiceable:, actor: nil)
        return nil unless Config.enabled?
        return nil unless Config.manual_actions_enabled?

        AutoIssueService.call(invoiceable: invoiceable, actor: actor, force: true)
      end
    end
  end
end
