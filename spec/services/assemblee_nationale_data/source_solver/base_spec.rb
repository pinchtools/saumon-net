require 'rails_helper'

RSpec.describe AssembleeNationaleData::SourceSolver::Base do
  let(:source) { create(:source) }
  let(:download) { create(:download, source: source) }
  let(:extracted_file1) { create(:extracted_file, download: download, updated_at: older_time) }
  let(:extracted_file2) { create(:extracted_file, download: download, updated_at: newer_time) }
  let(:service) { described_class.new }

  let(:older_time) { 1.hour.ago }
  let(:newer_time) { Time.current }
  let(:parsed_data) { { uid: "test", type: "acteur" } }

  before do
    allow(AssembleeNationaleData::ExtractedFileParserService).to receive(:new).and_return(double(call: parsed_data))
  end

  describe "#compare" do
    context "when extracted_file2 is newer" do
      it "returns response with replace true and data" do
        result = service.compare(extracted_file1, extracted_file2)

        expect(result.replace?).to be true
        expect(result.data).to eq(parsed_data)
      end
    end

    context "when extracted_file1 is newer" do
      let(:older_time) { Time.current }
      let(:newer_time) { 1.hour.ago }

      it "returns response with replace false and no data" do
        result = service.compare(extracted_file1, extracted_file2)

        expect(result.replace?).to be false
        expect(result.data).to be_nil
      end
    end

    context "when files have same updated_at" do
      let(:older_time) { Time.current }
      let(:newer_time) { older_time }

      it "returns response with replace false" do
        result = service.compare(extracted_file1, extracted_file2)

        expect(result.replace?).to be false
      end
    end
  end
end
