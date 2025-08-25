class AssembleeNationaleData::ExtractedFileParserService
  include Telescope::Rescuable

  class MissingDataError < StandardError; end

  attr_reader :extracted_file

  def initialize(extracted_file)
    @extracted_file = extracted_file
  end

  def call
    parsed_data = JSON.parse(file_content)

    parsed_data.deep_transform_keys! { |k| k.to_s.underscore.to_sym }

    extract_entity_data(parsed_data)
  rescue MissingDataError => e
    Telescope.capture_error(e, context: { extracted_file_id: extracted_file.id })
  end

  private

  def file_content
    @file_content ||= extracted_file.file.download
  end

  def extract_entity_data(parsed_data)
    root_key = parsed_data.keys.first

    if root_key.nil?
      raise MissingDataError, "Missing root key in #{parsed_data}"
    end

    root_data = parsed_data[root_key]
    return {} unless root_data.is_a?(Hash)

    {
      uid: uid,
      type: normalize_to_ascii(root_key),
      metadata: extract_metadata(root_data),
      download_id: extracted_file.download_id,
      root_data: root_data
    }
  end

  def normalize_to_ascii(text)
    text.to_s.unicode_normalize(:nfd)
        .encode("ASCII", undef: :replace, invalid: :replace, replace: "")
        .gsub(/[^A-Za-z0-9]/, "")
  end

  def uid
    [ extracted_file.download.source.code, extracted_file.file_name ].join("-").upcase
  end

  def extract_metadata(data)
    metadata = {}

    data.each do |key, value|
      if !value.is_a?(Hash) && !value.is_a?(Array)
        metadata[key] = value
      elsif value.is_a?(Hash) && key == :uid
        metadata[key] = value
      end
    end

    metadata
  end
end
