class AssembleeNationaleData::ProcessDownloadedResourceJob < ApplicationJob
  queue_as :default

  def perform(download_id)
  end
end
