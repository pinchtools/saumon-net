class AssembleeNationaleData::EntityUpserterService
  include Telescope::Rescuable

  attr_reader :extracted_file

  def initialize(extracted_file)
    @extracted_file = extracted_file
  end

  def call
    return unless extracted_file&.file&.attached?

    if entity.new_record?
      data = AssembleeNationaleData::ExtractedFileParserService.new(extracted_file).call
    else
      result = compare_files(entity.extracted_file, extracted_file)

      if result.replace?
        data = result.data
      else
        Telescope::LogJob.perform_later("Entity already exists and no replacement is required.",
                                        context: {
                                          old_extracted_file_id: entity.extracted_file_id,
                                          new_extracted_file_id: extracted_file.id
                                        })
        return
      end
    end

    upsert_entity(data)
  end

  private

  def entity
    @entity ||= Entity.find_or_initialize_by(uid: uid)
  end

  def uid
    @uid ||= [ extracted_file.download.source.code, extracted_file.file_name ].join("-").upcase
  end

  def compare_files(existing_extracted_file, new_extracted_file)
    source_solver.compare(existing_extracted_file, new_extracted_file)
  end

  def source_solver
    @source_solver ||= AssembleeNationaleData::SourceSolverFactory.for(entity.type)
  end

  def upsert_entity(data)
    entity.extracted_file = extracted_file
    entity.download = extracted_file.download

    entity.assign_attributes(
      type: data[:type],
      metadata: data[:metadata],
      download_id: data[:download_id]
    )

    entity.tap(&:save!)
  end
end
