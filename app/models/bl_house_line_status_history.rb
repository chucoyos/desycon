class BlHouseLineStatusHistory < ApplicationRecord
  belongs_to :bl_house_line
  belongs_to :user, optional: true
end
