require 'rails_helper'

RSpec.describe Source, type: :model do
  describe "relationships" do
    it { should have_many(:downloads) }
  end

  describe "validations" do
    let(:name) { "AN_OPENDATA" }
    let(:code) { "ABC" }
    subject { create(:source, name: name, code: code) }

    it { expect(subject).to be_valid }

    context "when name is blank" do
      let(:name) { nil }

      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end

    context "when code is blank" do
      let(:code) { nil }

      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end

    context "when code already exists" do
      let(:code) { "ABC" }
      let!(:another_source) { create(:source, code: code) }

      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end
  end
end
