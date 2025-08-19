require 'rails_helper'

RSpec.describe AssembleeNationaleData::DownloadResourceWithScraperJob, type: :job do
  include ActiveJob::TestHelper

  let(:dataset_type) { 'deputes' }
  let(:dataset_code) { 'current' }
  let(:scraper) { instance_double(AssembleeNationaleData::Scraper) }
  let(:download) { double('Download', id: 123) }
  let(:current_time) { Time.current }

  before do
    allow(AssembleeNationaleData::Scraper).to receive(:new).and_return(scraper)
    allow(Time).to receive(:current).and_return(current_time)
  end

  describe '#perform' do
    context 'when scraper returns a download' do
      before do
        allow(scraper).to receive(:fetch_dataset).with(dataset_type, dataset_code)
                                                 .and_return(download)
      end

      it 'fetches the dataset using scraper' do
        subject.perform(dataset_type, dataset_code)

        expect(scraper).to have_received(:fetch_dataset).with(dataset_type, dataset_code)
      end

      it 'enqueues completion event job' do
        expect {
          subject.perform(dataset_type, dataset_code)
        }.to have_enqueued_job(EventJob)
               .with("anod.download_resource.completed", {
                 download_id: download.id,
                 triggered_ts: current_time.to_i
               })
      end
    end

    context 'when scraper returns nil' do
      before do
        allow(scraper).to receive(:fetch_dataset).with(dataset_type, dataset_code)
                                                 .and_return(nil)
      end

      it 'does not enqueue event job' do
        expect {
          subject.perform(dataset_type, dataset_code)
        }.not_to have_enqueued_job(EventJob)
      end
    end
  end

  describe 'job configuration' do
    it 'queues on low priority' do
      expect(described_class.queue_name).to eq('low')
    end
  end
end
