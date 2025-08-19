class AssembleeNationaleData::DownloadResourcesJob < ApplicationJob
  queue_as :default

  def perform
    AssembleeNationaleData::Configurable.flattened_scraper_config_file.each do |dataset_code, attrs|
      AssembleeNationaleData::DownloadResourceWithScraperJob.perform_later(attrs["dataset_type"], dataset_code)
    end
  end
end
