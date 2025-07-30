require 'rails_helper'

RSpec.describe Entity, type: :model do
  describe "relationships" do
    it { should belong_to :download }
  end

  describe "validations" do
    let(:uid) { "PA123" }
    let(:type) { "AN-VOTE" }
    subject { create(:entity, uid: uid, type: type) }

    it { expect(subject).to be_valid }

    context "uid is missing" do
      let(:uid) { nil }
      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end

    context "uid already exists" do
      let!(:another_entity) { create(:entity, uid: uid) }
      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end

    context "type is missing" do
      let(:type) { nil }
      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end
  end
end
