class AssembleeNationaleData::ProcessDownloadedResourceJob < ApplicationJob
  queue_as :default

  def perform(download_id)
    download = Download.find(download_id)
    @process = AssembleeNationaleData::DownloadedResourceProcessorService.new(download).call

    context = { download_id: download_id, triggered_ts: Time.current.to_i }
    if @process.success?
      trigger_completed_extraction_file_events if extracted_files?

      Telescope::LogJob.perform_later("Successfully processed the resource attached to the download", context)
    else
      Telescope::LogJob.perform_later("An error occurred while trying to process the attached resource", context)
    end
  rescue ActiveRecord::RecordNotFound => e
    Telescope.capture_error(e, context: { download_id: download_id })
  end

  private

  def extracted_files?
    @process.data.extracted_file_ids.present?
  end

  def trigger_completed_extraction_file_events
    @process.data.extracted_file_ids.each do |id|
      EventJob.perform_later("anod.file_extraction.completed", { file_id: id })
    end
  end
end
