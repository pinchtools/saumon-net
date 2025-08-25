require 'rails_helper'

RSpec.describe AssembleeNationaleData::SourceSolver::Actor do
  let(:source) { create(:source) }
  let(:download) { create(:download, source: source) }
  let(:extracted_file1) { create(:extracted_file, download: download) }
  let(:extracted_file2) { create(:extracted_file, download: download) }
  let(:service) { described_class.new }

  let(:file1_mandats_count) { 2 }
  let(:file2_mandats_count) { 3 }
  let(:file1_data) { { root_data: { mandats: Array.new(file1_mandats_count) } } }
  let(:file2_data) { { root_data: { mandats: Array.new(file2_mandats_count) } } }

  before do
    allow(AssembleeNationaleData::ExtractedFileParserService)
      .to receive(:new)
            .with(extracted_file1)
            .and_return(double(call: file1_data))

    allow(AssembleeNationaleData::ExtractedFileParserService)
      .to receive(:new)
            .with(extracted_file2)
            .and_return(double(call: file2_data))
  end

  describe "#compare" do
    context "when file2 has more mandats than file1" do
      it "returns response with replace true" do
        result = service.compare(extracted_file1, extracted_file2)

        expect(result.replace?).to be true
        expect(result.data).to eq(file2_data)
      end
    end

    context "when file2 has same number of mandats as file1" do
      let(:file2_mandats_count) { 2 }

      it "returns response with replace false" do
        result = service.compare(extracted_file1, extracted_file2)

        expect(result.replace?).to be false
        expect(result.data).to be_nil
      end
    end

    context "when file2 has fewer mandats than file1" do
      let(:file2_mandats_count) { 1 }

      it "returns response with replace false" do
        result = service.compare(extracted_file1, extracted_file2)

        expect(result.replace?).to be false
        expect(result.data).to be_nil
      end
    end
  end
end
