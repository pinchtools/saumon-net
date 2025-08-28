class AssembleeNationaleData::UpsertEntityJob < ApplicationJob
  queue_as :default

  def perform(file_id)
    extracted_file = ExtractedFile.find(file_id)
    entity = AssembleeNationaleData::EntityUpserterService.new(extracted_file).call

    if entity.present?
      EventJob.perform_later("anod.entity.upserted", { entity_id: entity.id, triggered_ts: Time.current.to_i })
    end

  rescue ActiveRecord::RecordNotFound => e
    Telescope.capture_error(e)
  end
end
