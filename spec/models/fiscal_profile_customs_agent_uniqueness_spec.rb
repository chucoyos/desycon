require 'rails_helper'

RSpec.describe FiscalProfile, "RFC uniqueness for customs agents and clients", type: :model do
  let(:agent) { create(:entity, :customs_agent) }
  before do
    create(:fiscal_profile, profileable: agent, rfc: 'AGE850101AB1')
    agent.reload
  end

  it 'allows editing name and fiscal profile of the customs agent itself' do
    agent.name = 'Agencia Renombrada'
    agent.fiscal_profile.razon_social = 'Agencia Renombrada SA de CV'

    expect(agent.save).to be(true), -> { agent.errors.full_messages.to_sentence }
    expect(agent.reload.fiscal_profile.razon_social).to eq('Agencia Renombrada SA de CV')
  end

  it 'allows the agent to keep an RFC also used by a client of another agent' do
    other_agent = create(:entity, :customs_agent)
    client = create(:entity, :client, customs_agent: other_agent)
    create(:fiscal_profile, profileable: client, rfc: 'AGE850101AB1')

    agent.fiscal_profile.razon_social = 'Otra Razon SA'
    expect(agent.fiscal_profile).to be_valid
  end

  it 'rejects two clients with the same RFC under the same agent' do
    create(:fiscal_profile, profileable: create(:entity, :client, customs_agent: agent), rfc: 'CLI850101AB1')
    duplicate = build(:fiscal_profile, profileable: create(:entity, :client, customs_agent: agent), rfc: 'cli850101ab1')

    expect(duplicate).not_to be_valid
    expect(duplicate.errors[:rfc]).to be_present
  end

  it 'allows the same RFC for clients of different agents' do
    other_agent = create(:entity, :customs_agent)
    create(:fiscal_profile, profileable: create(:entity, :client, customs_agent: agent), rfc: 'CLI850101AB1')
    other = build(:fiscal_profile, profileable: create(:entity, :client, customs_agent: other_agent), rfc: 'CLI850101AB1')

    expect(other).to be_valid
  end

  it 'ignores the client itself when editing its own profile' do
    client = create(:entity, :client, customs_agent: agent)
    profile = create(:fiscal_profile, profileable: client, rfc: 'CLI850101AB1')
    profile.razon_social = 'Cliente Editado SA'

    expect(profile).to be_valid
  end
end
