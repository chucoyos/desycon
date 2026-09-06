require "rails_helper"

RSpec.describe ConsolidatorApiCredential, type: :model do
  describe ".issue! and .authenticate" do
    it "stores only a digest and authenticates the returned key" do
      entity = create(:entity, :consolidator)

      credential, raw_key = described_class.issue!(entity: entity, name: "ERP production")

      expect(credential.key_digest).not_to eq(raw_key)
      expect(credential.key_digest).to eq(described_class.digest_for(raw_key))
      expect(described_class.authenticate(raw_key)).to eq(credential)
      expect(described_class.authenticate("invalid-key")).to be_nil
    end

    it "rejects credentials for non-consolidator entities" do
      expect {
        described_class.issue!(entity: create(:entity, :client), name: "Invalid")
      }.to raise_error(ArgumentError, "Entity must be a consolidator")
    end

    it "does not authenticate revoked or expired credentials" do
      entity = create(:entity, :consolidator)
      credential, raw_key = described_class.issue!(entity: entity, name: "Temporary", expires_at: 1.minute.from_now)

      credential.revoke!
      expect(described_class.authenticate(raw_key)).to be_nil

      expired_credential, expired_key = described_class.issue!(entity: entity, name: "Expired", expires_at: 1.minute.ago)
      expect(expired_credential).to be_persisted
      expect(described_class.authenticate(expired_key)).to be_nil
    end
  end
end
