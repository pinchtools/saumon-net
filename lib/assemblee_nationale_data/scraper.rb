# lib/assemblee_nationale_data/scraper.rb
module AssembleeNationaleData
  class Scraper
    include Rescuable
    include Configurable

    SOURCE_TYPE = "ANOD".freeze

    def initialize
      @headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      }

      @config_file = YAML.load_file(Rails.root.join("config", "lib", "assemblee_nationale_data", "scraper.yml"))

      @source = Source.find_by_code!(SOURCE_TYPE)
    end

    def fetch_dataset(dataset_type, dataset_code, file_format: "json")
      config = load_dataset_config(dataset_type, dataset_code)

      if config.nil?
        raise StandardError, "Missing configuration for dataset: #{dataset_type}/#{dataset_code}"
      end

      response = HTTParty.get([ base_url, config.dig("url") ].join, headers: @headers)

      unless response.success?
        raise NetworkError, "Failed to fetch data: #{response.code}"
      end

      doc = Nokogiri::HTML(response.body)

      # Look for download links
      json_link = doc.xpath("//a[contains(@href, '#{config.dig("code")}')]").
        map { |ll| ll.attr("href") }.
        uniq.
        find { |link| link.end_with?(".#{file_format}", ".#{file_format}.zip") }

      if json_link.nil?
        raise StandardError, "No download link found for #{dataset_type}/#{dataset_code}"
      end

      json_uri = URI.parse(json_link)

      if json_uri.relative?
        json_link.prepend("/") unless json_link.start_with?("/")
        json_link.prepend(base_url)
        json_uri = URI.parse(json_link)
      end

      save_file(json_uri, dataset_code)
    rescue NetworkError => e
      # we re-raised network error so it can be retry by async job
      raise e
    rescue => e
      Telescope.capture_error(e, error_context)
      nil
    end

    private

    def load_dataset_config(dataset_type, dataset_code)
      @config_file.dig(SOURCE_TYPE, dataset_type, dataset_code)
    end

    def save_file(uri, dataset_code)
      # todo should check the fingerprint before instantiating && the checksum
      # create a specific service to return a download to attach the file or return nil
      # when we have to ignore the download
      fingerprint = Digest::MD5.hexdigest(dataset_code + uri.to_s)
      name = uri.path.split("/").last

      download = @source.downloads.new(fingerprint: fingerprint, name: name)

      download_file(uri.to_s) do |response|
        download.file.attach(
          io: StringIO.new(response.body),
          filename: name,
          content_type: response.headers["content-type"]  # Gets content type from response
        )
      end

      download.tap(&:save!)
    end

    def download_file(url)
      return nil unless url

      raise StandardError, "Expect a block to be given" unless block_given?

      full_url = url.start_with?("http") ? url : "#{AssembleeNationaleData.base_url}#{url}"
      response = HTTParty.get(full_url, headers: @headers)

      raise NetworkError, "Failed to download file from #{url}: #{response.code}" unless response.success?

      yield response
    end
  end
end
