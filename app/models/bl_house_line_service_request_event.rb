class BlHouseLineServiceRequestEvent < ApplicationRecord
  belongs_to :bl_house_line_service_request
  belongs_to :actor, class_name: "User"

  validates :action, presence: true
end
