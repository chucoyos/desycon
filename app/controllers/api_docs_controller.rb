class ApiDocsController < ApplicationController
  before_action :authenticate_user!

  DOC_PATHS = {
    consolidator: Rails.root.join("docs/consolidator_api.md")
  }.freeze

  def consolidator
    authorize :api_doc, :consolidator?

    @markdown = DOC_PATHS.fetch(:consolidator).read
  end
end
