require 'rails_helper'

RSpec.describe Role, type: :model do
  describe 'dependent restrictions' do
    it 'prevents deletion when users exist' do
      role = create(:role)
      create(:user, role: role)

      role.destroy

      expect(role.destroyed?).to be_falsey
      expect(role.errors).not_to be_empty
      expect(Role.exists?(role.id)).to be_truthy
    end

    it 'allows deletion when no dependent users exist' do
      role = create(:role)

      expect { role.destroy }.to change(Role, :count).by(-1)
    end
  end
end
