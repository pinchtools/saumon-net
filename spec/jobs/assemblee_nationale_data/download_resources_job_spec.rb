require 'rails_helper'

RSpec.describe AssembleeNationaleData::DownloadResourcesJob, type: :job do
  include ActiveJob::TestHelper

  let(:flattened_config) do
    {
      "current" => {
        "dataset_type" => "deputes",
        "url" => "deputes/current",
        "code" => "deputes_current"
      },
      "2022" => {
        "dataset_type" => "votes",
        "url" => "votes/2022",
        "code" => "votes_2022"
      }
    }
  end

  before do
    allow(AssembleeNationaleData::Configurable).to receive(:flattened_scraper_config_file)
                                                     .and_return(flattened_config)
  end

  describe '#perform' do
    it 'enqueues download jobs for each dataset' do
      expect {
        subject.perform
      }.to have_enqueued_job(AssembleeNationaleData::DownloadResourceWithScraperJob)
             .with("deputes", "current")
             .and have_enqueued_job(AssembleeNationaleData::DownloadResourceWithScraperJob)
                    .with("votes", "2022")
    end
  end

  describe 'job configuration' do
    it 'queues on default' do
      expect(described_class.queue_name).to eq('default')
    end
  end
end
