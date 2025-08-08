require 'rails_helper'

RSpec.describe Download, type: :model do
  describe "relations" do
    it { should belong_to(:source) }
    it { should have_one_attached(:file) }
  end

  describe "validations" do
    let(:fingerprint) {  "A1234" }
    let(:name) { "AMP1234.csv" }
    let(:version) { 1 }
    let(:current) { true }
    subject { create(:download, name: name, fingerprint: fingerprint, version: version, current: current) }

    it { expect(subject).to be_valid }

    context "name is missing" do
      let(:name) { nil }

      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end

    context "fingerprint is missing" do
      let(:fingerprint) { "" }

      it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
    end

    context "fingerprint already exists" do
      context "with same version file" do
        let!(:another_download) { create(:download, fingerprint: fingerprint, version: version) }
        it { expect { subject.valid }.to raise_error(ActiveRecord::RecordInvalid) }
      end

      context "with a different version file" do
        context "and is considered as the current one" do
          let!(:another_download) { create(:download, fingerprint: fingerprint, version: 2, current: true) }
          it { expect { subject.valid }.to raise_error(ActiveRecord::RecordNotUnique) }
        end

        context "and is not the current one" do
          let!(:another_download) { create(:download, fingerprint: fingerprint, version: 2, current: false) }
          it { expect(subject).to be_valid }
        end
      end
    end
  end
end
