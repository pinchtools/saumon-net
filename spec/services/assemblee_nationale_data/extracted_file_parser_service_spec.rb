require 'rails_helper'

RSpec.describe AssembleeNationaleData::ExtractedFileParserService do
  let(:source) { create(:source, code: source_code) }
  let(:download) { create(:download, source: source) }
  let(:blob) { instance_double('ActiveStorage::Blob', download: json_content) }
  let(:file) { double('ActiveStorage::Attached::One') }
  let(:extracted_file) { create(:extracted_file, download: download, path: file_path) }
  let(:service) { described_class.new(extracted_file) }


  let(:source_code) { "ANOD" }
  let(:file_path) { "actor/PA123456.json" }
  let(:file_name) { "PA123456" }
  let(:expected_uid) { "ANOD-PA123456" }
  let(:date_creation) { "2021-11-22T15:46:09.483279+00:00" }
  let(:legislature) { "17" }

  describe "#call" do
    let(:json_content) { file_content.to_json }

    before do
      allow(extracted_file).to receive(:file).and_return(file)
      allow(extracted_file.file).to receive(:download).and_return(json_content)
    end

    context "with valid JSON containing actor data" do
      let(:file_content) do
        {
          acteur: {
            dateCreation: date_creation,
            legislature: legislature,
            details: {
              profession: "Député"
            },
            uid: {
              internal_id: expected_internal_id
            }
          }
        }
      end
      let(:expected_internal_id) { "12345" }
      let(:type) { "acteur" }

      it "returns parsed entity data" do
        result = service.call

        expect(result).to include(
                            uid: expected_uid,
                            type: type,
                            download_id: download.id
                          )
      end

      it "returns normalized data" do
        result = service.call

        expect(result[:root_data]).to eq({
                                           date_creation: date_creation,
                                           legislature: legislature,
                                           details: {
                                             profession: "Député"
                                           },
                                           uid: {
                                             internal_id: expected_internal_id
                                           }
                                         })
      end

      it "extracts metadata excluding nested objects" do
        result = service.call

        expect(result[:metadata]).to include(
                                       date_creation: date_creation,
                                       legislature: legislature,
                                       uid: { internal_id: expected_internal_id }
                                     )
      end

      it "excludes nested objects from metadata" do
        result = service.call

        expect(result[:metadata]).not_to have_key(:details)
      end
    end

    context "with accented characters in root key" do
      let(:file_content) do
        {
          "député" => {
            nom: "Martin",
            circonscription: expected_circonscription
          }
        }
      end
      let(:expected_circonscription) { "Paris 1ère" }

      it "normalizes type to ASCII" do
        result = service.call

        expect(result[:type]).to eq("depute")
      end
    end

    context "with special characters in root key" do
      let(:file_content) do
        {
          "acteur-2024" => {
            nom: "Durand"
          }
        }
      end

      it "removes non-alphanumeric characters" do
        result = service.call

        expect(result[:type]).to eq("acteur2024")
      end
    end

    context "with empty JSON object" do
      let(:file_content) { {} }

      before do
        allow(Telescope).to receive(:capture_error)
      end

      it "captures error and returns nil" do
        result = service.call

        expect(result).to be_nil
        expect(Telescope).to have_received(:capture_error).with(
          an_instance_of(AssembleeNationaleData::ExtractedFileParserService::MissingDataError),
          context: { extracted_file_id: extracted_file.id }
        )
      end
    end

    context "with invalid JSON" do
      let(:json_content) { "invalid json" }

      it "raises JSON::ParserError" do
        expect { service.call }.to raise_error(JSON::ParserError)
      end
    end
  end

  describe "#normalize_to_ascii" do
    let(:normalize_method) { service.send(:normalize_to_ascii, input_text) }

    context "with accented characters" do
      let(:input_text) { "député" }

      it "converts to ASCII" do
        expect(normalize_method).to eq("depute")
      end
    end

    context "with special characters" do
      let(:input_text) { "acteur-2024_test!" }

      it "removes non-alphanumeric characters" do
        expect(normalize_method).to eq("acteur2024test")
      end
    end

    context "with mixed case" do
      let(:input_text) { "ActeurTest" }

      it "preserves case" do
        expect(normalize_method).to eq("ActeurTest")
      end
    end
  end

  describe "#uid" do
    it "generates UID from source code and file name" do
      expect(service.send(:uid)).to eq(expected_uid)
    end
  end

  describe "#extract_metadata" do
    let(:extract_metadata_method) { service.send(:extract_metadata, input_data) }

    context "with primitive values" do
      let(:input_data) do
        {
          nom: "Dupont",
          age: expected_age,
          active: true
        }
      end
      let(:expected_age) { 35 }

      it "includes all primitive values" do
        expect(extract_metadata_method).to eq(input_data)
      end
    end

    context "with uid hash" do
      let(:input_data) do
        {
          nom: "Dupont",
          uid: {
            internal_id: expected_internal_id
          }
        }
      end
      let(:expected_internal_id) { "67890" }

      it "includes uid hash" do
        expect(extract_metadata_method).to include(
                                             uid: { internal_id: expected_internal_id }
                                           )
      end
    end

    context "with other nested objects" do
      let(:input_data) do
        {
          nom: "Dupont",
          details: {
            profession: "Député"
          }
        }
      end

      it "excludes non-uid nested objects" do
        expect(extract_metadata_method).to eq(nom: "Dupont")
      end
    end
  end
end
