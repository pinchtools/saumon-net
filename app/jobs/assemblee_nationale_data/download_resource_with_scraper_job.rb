class AssembleeNationaleData::DownloadResourceWithScraperJob < ApplicationJob
  queue_as :low

  def perform(dataset_type, dataset_code)
    download = AssembleeNationaleData::Scraper.new.fetch_dataset(dataset_type, dataset_code)

    if download.present?
      EventJob.perform_later("anod.download_resource.completed", {
        download_id: download.id,
        triggered_ts: Time.current.to_i
      })
    end
  end
end
