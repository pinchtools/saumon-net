# lib/assemblee_nationale_data/scraper.rb
module AssembleeNationaleData
  class Scraper
    include Configurable

    def initialize
      @headers = {
        'User-Agent' => 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36'
      }

      @config_file = YAML.load_file(Rails.root.join('config', 'lib', 'assemblee_nationale_data', 'scraper.yml'))
    end

    def fetch_dataset(dataset_type, dataset_code)
      config = load_dataset_config(dataset_type, dataset_code)

      response = HTTParty.get([base_url, config.dig("url")].join, headers: @headers)

      if response.success?
        doc = Nokogiri::HTML(response.body)

        # Look for download links
        json_link = doc.xpath("//a[contains(@href, '#{config.dig("code")}')]").first&.attr("href")
        json_uri  = URI.parse(json_link)

        if json_uri.host.nil?
          json_link.prepend(base_url)
        end

        downloads = {
          json: json_link
        }
        #json: download_file(json_link)

        #save_files(downloads)

        downloads
      else
        puts "Failed to fetch data: #{response.code}"
        nil
      end
    end

    private

    def load_dataset_config(dataset_type, dataset_code)
      @config_file.dig(dataset_type, dataset_code)
    end

    def download_file(url)
      return nil unless url

      full_url = url.start_with?('http') ? url : "#{AssembleeNationaleData.base_url}#{url}"
      response = HTTParty.get(full_url, headers: @headers)

      if response.success?
        response.body
      else
        puts "Failed to download file from #{url}: #{response.code}"
        nil
      end
    end

    def save_files(downloads)
      downloads.each do |format, content|
        next if content.nil?

        filename = "deputies.#{format}"
        File.write(filename, content)
        puts "Saved #{filename}"
      end
    end
  end
end
