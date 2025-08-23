class AssembleeNationaleData::ProcessDownloadedResourceJob < ApplicationJob
  queue_as :default

  def perform(download_id)
    @process = AssembleeNationaleData::DownloadedResourceProcessorService.new(download_id).call

    context = { download_id: download_id, triggered_ts: Time.current.to_i }
    if @process.success?
      trigger_completed_extraction_file_events if extracted_files?

      Telescope::LogJob.perform_later("Successfully processed the resource attached to the download", context)
    else
      Telescope::LogJob.perform_later("An error occurred while trying to process the attached resource", context)
    end
  end

  private

  def extracted_files?
    @process.extracted_file_ids.present?
  end

  def trigger_completed_extraction_file_events
    @process.extracted_file_ids.each do |id|
      EventJob.perform_later("anod.file_extraction.completed", id)
    end
  end
end
