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
          return download
        end
      else
        attach_file(download, file_content)
      end

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
      source: source
    ).call
    download.name = filename
    download
  end

  def download_file_content
    @file_content ||= begin
                        response = nil
                        HTTParty.get(uri.to_s, headers: download_headers) do |chunk|
                          response = chunk
                        end

                        raise Telescope::NetworkError, "Failed to download: #{response.code}" unless response.success?
                        response
                      end
  end

  def file_needs_update?(download, file_content)
    new_checksum = Digest::MD5.hexdigest(file_content.body)

    download.file.checksum != new_checksum
  end

  def create_new_version(current_download)
    DownloadVersioningService.new(
      name: current_download.name,
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
