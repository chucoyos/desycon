require 'rails_helper'

RSpec.describe EntityEmailRecipient, type: :model do
  describe 'validations' do
    it 'normalizes email before validation' do
      recipient = build(:entity_email_recipient, email: '  TEST@Correo.COM  ')
      recipient.validate

      expect(recipient.email).to eq('test@correo.com')
    end

    it 'allows only customs agencies and consolidators' do
      client_entity = create(:entity, :client)
      recipient = build(:entity_email_recipient, entity: client_entity)

      expect(recipient).not_to be_valid
      expect(recipient.errors[:entity]).to include('solo puede configurar correos para agencia aduanal o consolidador')
    end

    it 'orders by primary first and then position' do
      entity = create(:entity, :customs_agent)
      create(:entity_email_recipient, entity: entity, email: 'b@correo.com', primary_recipient: false, position: 2)
      create(:entity_email_recipient, entity: entity, email: 'a@correo.com', primary_recipient: true, position: 5)
      create(:entity_email_recipient, entity: entity, email: 'c@correo.com', primary_recipient: false, position: 1)

      ordered = entity.entity_email_recipients.active.ordered.pluck(:email)
      expect(ordered).to eq([ 'a@correo.com', 'c@correo.com', 'b@correo.com' ])
    end
  end
end
