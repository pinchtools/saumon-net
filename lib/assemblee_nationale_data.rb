# lib/assemblee_nationale_data.rb
require 'nokogiri'
require 'httparty'
require 'json'
require 'yaml'

module AssembleeNationaleData
  class Error < StandardError; end

  class << self
    attr_accessor :base_url
  end

  # Set the default base URL
  @base_url = ENV['AN_DATA_DOMAIN']

  autoload :Configurable, 'assemblee_nationale_data/configurable'
  autoload :Scraper, 'assemblee_nationale_data/scraper'
  autoload :Version, 'assemblee_nationale_data/version'
end
