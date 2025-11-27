require 'rails_helper'

RSpec.describe ShippingLinePolicy, type: :policy do
  subject { described_class.new(user, shipping_line) }

  let(:shipping_line) { ShippingLine.new }
  let(:admin_role) { Role.new(name: Role::ADMIN) }
  let(:operator_role) { Role.new(name: Role::OPERATOR) }
  let(:customs_broker_role) { Role.new(name: Role::CUSTOMS_BROKER) }

  context 'for an admin user' do
    let(:user) { User.new(role: admin_role) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.to permit_action(:destroy) }
  end

  context 'for an operator user' do
    let(:user) { User.new(role: operator_role) }

    it { is_expected.to permit_action(:index) }
    it { is_expected.to permit_action(:show) }
    it { is_expected.to permit_action(:create) }
    it { is_expected.to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
  end

  context 'for a customs broker user' do
    let(:user) { User.new(role: customs_broker_role) }

    it { is_expected.not_to permit_action(:index) }
    it { is_expected.not_to permit_action(:show) }
    it { is_expected.not_to permit_action(:create) }
    it { is_expected.not_to permit_action(:update) }
    it { is_expected.not_to permit_action(:destroy) }
  end
end
