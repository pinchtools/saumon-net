module AssembleeNationaleData
  module Configurable
    class << self
      def base_url
        @base_url ||= AssembleeNationaleData.base_url
      end
      def scraper_config_file
        @scraper_config_file ||= YAML.load_file(Rails.root.join("config", "lib", "assemblee_nationale_data", "scraper.yml"))
      end

      def flattened_scraper_config_file
        scraper_config_file.flat_map do |code, types|
          types.flat_map do |type, confs|
            confs.map do |conf_name, attrs|
              [conf_name, attrs.merge("source_code" => code, "entity_type" => type)]
            end
          end
        end.to_h
      end
    end
  end
end
