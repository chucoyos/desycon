require 'rails_helper'

RSpec.describe BlHouseLineStatusHistory, type: :model do
  describe 'associations' do
    it 'belongs to bl_house_line' do
      association = described_class.reflect_on_association(:bl_house_line)
      expect(association.macro).to eq(:belongs_to)
    end

    it 'belongs to user as optional' do
      association = described_class.reflect_on_association(:user)
      expect(association.macro).to eq(:belongs_to)
      expect(association.options[:optional]).to be(true)
    end
  end

  describe 'valid record' do
    it 'is valid without user' do
      history = create(:bl_house_line_status_history, bl_house_line: create(:bl_house_line), user: nil)
      expect(history).to be_valid
    end
  end
end
