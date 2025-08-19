require "ostruct"
class DownloadProcessorService
  include Telescope::Rescuable

  attr_reader :uri, :dataset_code, :source

  def initialize(uri:, dataset_code:, source:)
    @uri = uri
    @dataset_code = dataset_code
    @source = source
  end

  def call
    ActiveRecord::Base.transaction do
      download = resolve_or_create_download
      file_content = download_file_content

      if download.file.attached?
        if file_needs_update?(download, file_content)
          download = create_new_version(download)
          attach_file(download, file_content)
        else
          log_file_already_exists
          return nil
        end
      else
        attach_file(download, file_content)
      end

      download.checksum = checksum(file_content)
      download.tap(&:save!)
    end
  end


  private

  def fingerprint
    @fingerprint ||= Digest::MD5.hexdigest(dataset_code + uri.to_s)
  end

  def filename
    @filename ||= uri.path.split("/").last
  end

  def resolve_or_create_download
    download = CurrentDownloadResolverService.new(
      fingerprint: fingerprint,
      dataset_code: dataset_code,
      source: source
    ).call
    download.name = filename
    download
  end

  def download_file_content
    @file_content ||= begin
                        head_response = HTTParty.head(uri.to_s, headers: download_headers)
                        raise Telescope::NetworkError, "Failed to download: #{head_response.code}" unless head_response.success?

                        content = String.new
                        HTTParty.get(uri.to_s, headers: download_headers) do |chunk|
                          content << chunk.to_s
                        end

                        OpenStruct.new(
                          body: content,
                          headers: head_response.headers,
                          code: head_response.code
                        )
                      end
  end

  def file_needs_update?(download, file_content)
    new_checksum = checksum(file_content)

    download.checksum != new_checksum
  end

  def checksum(file_content)
    Digest::MD5.hexdigest(file_content.body)
  end

  def create_new_version(current_download)
    DownloadVersioningService.new(
      name: current_download.name,
      dataset_code: dataset_code,
      fingerprint: fingerprint,
      source: source
    ).call
  end

  def attach_file(download, file_content)
    download.file.attach(
      io: StringIO.new(file_content.body),
      filename: filename,
      content_type: file_content.headers["content-type"]
    )
  end

  def log_file_already_exists
    Telescope.log("File #{uri} is already downloaded", default_context)
  end

  def download_headers
    {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
  end
end
