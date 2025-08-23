require "ostruct"

class AssembleeNationaleData::DownloadedResourceProcessorService
  def initialize(download)
    @download = download
  end

  def call
    unless (validation = validate).success?
      return validation
    end

    process = case @download.file.blob.content_type
    when "application/zip"
                AssembleeNationaleData::ZipExtractorService.new(@download.file).call
    else
                failure("unsupported content type")
    end

    return failure("failed to process file") unless process.success?

    success
  end

  def validate
    return failure("missing parameters") unless @download.present?
    return failure("no file attached") unless @download.file.attached?

    true
  end

  def success
    OpenStruct.new(
      success?: true,
      error_message: nil
    )
  end

  def failure(message)
    OpenStruct.new(
      success?: false,
      error_message: message
    )
  end
end
