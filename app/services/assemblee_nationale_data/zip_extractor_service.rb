require "zip"
require "tempfile"
require "ostruct"

class AssembleeNationaleData::ZipExtractorService
  include Telescope::Rescuable

  attr_reader :attachment

  def initialize(attachment)
    @attachment = attachment
  end

  def call
    return failure("No attachment provided") unless attachment&.attached?
    return failure("File is not a zip archive") unless zip_file?

    unzip_and_attach_files
  end

  private

  def zip_file?
    attachment.blob.content_type == "application/zip" ||
      attachment.filename.to_s.downcase.end_with?(".zip")
  end

  def unzip_and_attach_files
    temp_zip_file = create_temp_zip_file
    extracted_file_ids = []

    begin
      download_blob_to_temp_file(temp_zip_file)

      Zip::File.open(temp_zip_file.path) do |zip_file|
        zip_file.each do |entry|
          next if entry.directory? || should_ignore_file?(entry)

          extracted_file = extract_and_attach_entry(entry)
          extracted_file_ids << extracted_file if extracted_file
        end
      end

      success(extracted_files_count: extracted_file_ids.count)
    rescue Zip::Error => e
      Telescope.capture_error(e, context: { attachment_id: attachment.id })
      failure("Failed to extract zip file: #{e.message}")
    rescue => e
      Telescope.capture_error(e, context: { attachment_id: attachment.id })
      failure("Unexpected error during extraction: #{e.message}")
    ensure
      cleanup_temp_file(temp_zip_file)
    end
  end

  def create_temp_zip_file
    Tempfile.new([ "active_storage_unzip", ".zip" ])
  end

  def download_blob_to_temp_file(temp_file)
    temp_file.binmode
    attachment.blob.download do |chunk|
      temp_file.write(chunk)
    end
    temp_file.rewind
  end

  def create_extracted_file(entry)
    attachment.record.extracted_files.create!(path: entry.name)
  end

  def extract_and_attach_entry(entry)
    file_content = StringIO.new(entry.get_input_stream.read)

    file_content.define_singleton_method(:original_filename) { File.basename(entry.name) }
    file_content.define_singleton_method(:content_type) { Marcel::MimeType.for(entry.name) }

    extract_file = create_extracted_file(entry)

    extract_file.file.attach(
      io: file_content,
      filename: File.basename(entry.name),
      content_type: file_content.content_type
    )

    extract_file
  end

  def scraper_configuration
    @scraper_configuration ||=
      AssembleeNationaleData::Configurable.flattened_scraper_config_file[attachment.record.dataset_code]
  end

  def should_ignore_file?(entry)
    whitelisted_directories = scraper_configuration&.dig("dirs") || []

    return false if whitelisted_directories.empty?

    whitelisted_directories.none? do |ignored_dir|
      entry.name.start_with?("#{ignored_dir}/")
    end
  end

  def cleanup_temp_file(temp_file)
    return unless temp_file

    temp_file.close
    temp_file.unlink
  rescue => e
    Telescope.capture_error(e, context: { message: "Failed to cleanup temp file" })
  end

  def success(data = {})
    OpenStruct.new(
      success?: true,
      failure?: false,
      data: data,
      error_message: nil
    )
  end

  def failure(message)
    OpenStruct.new(
      success?: false,
      failure?: true,
      data: nil,
      error_message: message
    )
  end
end
