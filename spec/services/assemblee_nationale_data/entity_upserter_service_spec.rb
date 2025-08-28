require 'rails_helper'

RSpec.describe AssembleeNationaleData::EntityUpserterService do
  subject(:service) { described_class.new(extracted_file) }

  let(:source) { create(:source, code: 'ANOD') }
  let(:download) { create(:download, source: source) }
  let(:extracted_file) { create(:extracted_file, download: download, path: 'actor/PA123456.json') }
  let(:parser_service) { instance_double('AssembleeNationaleData::ExtractedFileParserService') }
  let(:source_solver) { instance_double('AssembleeNationaleData::SourceSolver::Actor') }
  let(:comparison_result) { double('OpenStruct', replace?: false, data: nil) }
  let(:uid) { 'ANOD-PA123456' }
  let(:parsed_data) do
    {
      uid: uid,
      type: 'acteur',
      metadata: { nom: 'Dupont' },
      download_id: download.id
    }
  end
  let(:has_file) { true }
  let(:entity) do
    create(:entity, uid: uid, type: "another_type", extracted_file: existing_extracted_file, metadata: {})
  end

  before do
    allow(extracted_file).to receive_message_chain(:file, :attached?).and_return(has_file)
    allow(AssembleeNationaleData::ExtractedFileParserService).to receive(:new).with(extracted_file).and_return(parser_service)
    allow(AssembleeNationaleData::SourceSolverFactory).to receive(:for).and_return(source_solver)
    allow(Telescope::LogJob).to receive(:perform_later)
  end

  describe '#initialize' do
    it 'sets the extracted_file' do
      expect(service.extracted_file).to eq(extracted_file)
    end
  end

  describe '#call' do
    context 'when file is not attached' do
      let(:has_file) { false }

      it 'returns nil without processing' do
        expect(service.call).to be_nil
        expect(AssembleeNationaleData::ExtractedFileParserService).not_to have_received(:new)
      end
    end

    context 'when extracted_file is nil' do
      subject(:service) { described_class.new(nil) }

      it { expect(service.call).to be_nil }
    end

    context 'with new entity' do
      let(:entity) { Entity.new(uid: 'ANOD-PA123456') }

      before do
        allow(Entity).to receive(:find_or_initialize_by).with(uid: 'ANOD-PA123456').and_return(entity)
        allow(parser_service).to receive(:call).and_return(parsed_data)
        allow(entity).to receive(:save!).and_return(true)
      end

      it 'parses file and creates entity' do
        result = service.call

        expect(parser_service).to have_received(:call)
        expect(entity.type).to eq('acteur')
        expect(entity.metadata).to eq({ "nom" => 'Dupont' })
        expect(entity.download_id).to eq(download.id)
        expect(entity.extracted_file).to eq(extracted_file)
        expect(result).to eq(entity)
      end
    end

    context 'with existing entity that should be replaced' do
      let(:existing_extracted_file) { create(:extracted_file) }

      let(:comparison_result) { double('OpenStruct', replace?: true, data: parsed_data) }

      before do
        allow(Entity).to receive(:find_or_initialize_by).with(uid: entity.uid).and_return(entity)
        allow(source_solver).to receive(:compare).with(existing_extracted_file, extracted_file).and_return(comparison_result)
        allow(entity).to receive(:save!).and_return(true)
      end

      it 'compares files and updates entity when replacement needed' do
        result = service.call

        expect(source_solver).to have_received(:compare).with(existing_extracted_file, extracted_file)
        expect(entity.type).to eq('acteur')
        expect(entity.metadata).to eq({ "nom" => 'Dupont' })
        expect(result).to eq(entity)
      end
    end

    context 'with existing entity that should not be replaced' do
      let(:existing_extracted_file) { create(:extracted_file) }
      let(:comparison_result) { double('OpenStruct', replace?: false, data: parsed_data) }

      before do
        allow(Entity).to receive(:find_or_initialize_by).with(uid: entity.uid).and_return(entity)
        allow(source_solver).to receive(:compare).with(existing_extracted_file, extracted_file).and_return(comparison_result)
      end

      it 'logs message and returns nil' do
        result = service.call

        expect(Telescope::LogJob).to have_received(:perform_later).with(
          "Entity already exists and no replacement is required.",
          context: {
            old_extracted_file_id: existing_extracted_file.id,
            new_extracted_file_id: extracted_file.id
          }
        )
        expect(result).to be_nil
      end
    end
  end
end
