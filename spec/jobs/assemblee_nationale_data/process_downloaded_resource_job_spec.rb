require 'rails_helper'

RSpec.describe AssembleeNationaleData::ProcessDownloadedResourceJob, type: :job do
  subject(:job) { described_class.new }

  let(:download_id) { 123 }
  let(:processor_service) { instance_double(AssembleeNationaleData::DownloadedResourceProcessorService) }
  let(:process_result) { instance_double('ProcessResult') }
  let(:file_ids) { [ 1, 2, 3 ] }

  before do
    allow(AssembleeNationaleData::DownloadedResourceProcessorService).to receive(:new)
                                                   .with(download_id).and_return(processor_service)
    allow(processor_service).to receive(:call).and_return(process_result)
    allow(Telescope::LogJob).to receive(:perform_later)
    allow(EventJob).to receive(:perform_later)
  end

  describe '#perform' do
    context 'when processing succeeds' do
      before do
        expect(process_result).to receive(:success?).and_return(true)
        allow(process_result).to receive(:extracted_file_ids).and_return(file_ids)
      end

      it 'processes the download and logs success' do
        job.perform(download_id)

        expect(AssembleeNationaleData::DownloadedResourceProcessorService).to have_received(:new).with(download_id)
        expect(processor_service).to have_received(:call)
        expect(Telescope::LogJob).to have_received(:perform_later).with(
          "Successfully processed the resource attached to the download",
          { download_id: download_id, triggered_ts: instance_of(Integer) }
        )
      end

      it 'triggers file extraction events for each extracted file' do
        job.perform(download_id)

        file_ids.each do |file_id|
          expect(EventJob).to have_received(:perform_later).with("anod.file_extraction.completed", file_id)
        end
      end

      context 'when no files are extracted' do
        before do
          allow(process_result).to receive(:extracted_file_ids).and_return([])
        end

        it 'does not trigger extraction events' do
          job.perform(download_id)

          expect(EventJob).not_to have_received(:perform_later)
        end
      end
    end

    context 'when processing fails' do
      before do
        allow(process_result).to receive(:success?).and_return(false)
      end

      it 'logs error and does not trigger extraction events' do
        job.perform(download_id)

        expect(Telescope::LogJob).to have_received(:perform_later).with(
          "An error occurred while trying to process the attached resource",
          { download_id: download_id, triggered_ts: instance_of(Integer) }
        )
        expect(EventJob).not_to have_received(:perform_later)
      end
    end
  end

  describe '#extracted_files?' do
    before do
      allow(process_result).to receive(:extracted_file_ids).and_return(file_ids)
      job.instance_variable_set(:@process, process_result)
    end

    context 'when files are present' do
      let(:file_ids) { [ 1, 2 ] }

      it 'returns true' do
        expect(job.send(:extracted_files?)).to be true
      end
    end

    context 'when no files are present' do
      let(:file_ids) { [] }

      it 'returns false' do
        expect(job.send(:extracted_files?)).to be false
      end
    end
  end
end
