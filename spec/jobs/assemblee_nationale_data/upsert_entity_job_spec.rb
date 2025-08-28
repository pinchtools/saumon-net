require 'rails_helper'

RSpec.describe AssembleeNationaleData::UpsertEntityJob, type: :job do
  let(:extracted_file) { instance_double("ExtractedFile", id: 123) }
  let(:entity) { create(:entity) }
  let(:upserter_service) { instance_double('AssembleeNationaleData::EntityUpserterService') }
  let(:upserter_response) { entity }

  describe '#perform' do
    before do
      allow(ExtractedFile).to receive(:find).with(extracted_file.id).and_return(extracted_file)
      allow(AssembleeNationaleData::EntityUpserterService).to receive(:new).
        with(extracted_file).
        and_return(upserter_service)
      allow(upserter_service).to receive(:call).and_return(upserter_response)
    end

    context 'when service returns an entity' do
      before do
        allow(EventJob).to receive(:perform_later)
      end

      it 'calls the upserter service with extracted file' do
        subject.perform(extracted_file.id)

        expect(AssembleeNationaleData::EntityUpserterService).to have_received(:new).with(extracted_file)
        expect(upserter_service).to have_received(:call)
      end

      it 'triggers entity upserted event' do
        subject.perform(extracted_file.id)

        expect(EventJob).to have_received(:perform_later).with(
          "anod.entity.upserted",
          hash_including(
            entity_id: entity.id,
            triggered_ts: be_an(Integer)
          )
        )
      end
    end

    context 'when service returns nil' do
      let(:upserter_response) { nil }

      before do
        allow(EventJob).to receive(:perform_later)
        subject.perform(extracted_file.id)
      end

      it { expect(EventJob).not_to have_received(:perform_later) }
    end

    context 'when ExtractedFile is not found' do
      before do
        allow(ExtractedFile).to receive(:find).and_raise(ActiveRecord::RecordNotFound)
        allow(Telescope).to receive(:capture_error)
        subject.perform(999)
      end

      it 'captures the error' do
        expect(Telescope).to have_received(:capture_error).with(
          an_instance_of(ActiveRecord::RecordNotFound)
        )
      end

      it { expect(AssembleeNationaleData::EntityUpserterService).not_to have_received(:new) }
    end
  end
end
