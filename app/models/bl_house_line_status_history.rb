class BlHouseLineStatusHistory < ApplicationRecord
  belongs_to :bl_house_line
  belongs_to :changed_by, polymorphic: true, optional: true
end
