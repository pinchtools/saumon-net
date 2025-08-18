module AssembleeNationaleData
  class Scraper
    include Rescuable
    include Configurable

    SOURCE_TYPE = "ANOD".freeze

    def initialize
      @headers = {
        "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
      }
      @source = Source.find_by_code!(SOURCE_TYPE)
    end

    def fetch_dataset(dataset_type, dataset_code, file_format: "json")
      config = load_dataset_config(dataset_type, dataset_code)

      if config.nil?
        raise StandardError, "Missing configuration for dataset: #{dataset_type}/#{dataset_code}"
      end

      response = HTTParty.get([ Configurable.base_url, config.dig("url") ].join, headers: @headers)

      unless response.success?
        raise Telescope::NetworkError, "Failed to fetch data: #{response.code}"
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
        json_link.prepend(Configurable.base_url)
        json_uri = URI.parse(json_link)
      end

      save_file(json_uri, dataset_code)
    rescue Telescope::NetworkError => e
      # we re-raised network error so it can be retry by async job
      raise e
    rescue => e
      Telescope.capture_error(e, default_context)
      nil
    end

    private

    def load_dataset_config(dataset_type, dataset_code)
      Configurable.scraper_config_file.dig(SOURCE_TYPE, dataset_type, dataset_code)
    end

    def save_file(uri, dataset_code)
      DownloadProcessorService.new(
        uri: uri,
        dataset_code: dataset_code,
        source: @source
      ).call
    end
  end
end
