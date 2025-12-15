require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'dependent restrictions' do
    it 'prevents deletion when container_status_histories exist' do
      user = create(:user)
      create(:container_status_history, user: user)

      user.destroy

      expect(user.destroyed?).to be_falsey
      expect(user.errors).not_to be_empty
      expect(User.exists?(user.id)).to be_truthy
    end

    it 'prevents deletion when bl_house_line_status_histories exist' do
      user = create(:user)
      BlHouseLineStatusHistory.create!(bl_house_line: create(:bl_house_line), status: 'updated', previous_status: 'old', changed_at: Time.current, user: user)

      user.destroy

      expect(user.destroyed?).to be_falsey
      expect(user.errors).not_to be_empty
    end

    it 'allows deletion when no dependent records exist' do
      user = create(:user)

      expect { user.destroy }.to change(User, :count).by(-1)
    end
  end
end
