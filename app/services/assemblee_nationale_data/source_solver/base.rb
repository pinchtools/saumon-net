require "ostruct"

class AssembleeNationaleData::SourceSolver::Base
  include Telescope::Rescuable

  attr_reader :extracted_file1, :extracted_file2

  def compare(extracted_file1, extracted_file2)
    @extracted_file1 = extracted_file1
    @extracted_file2 = extracted_file2

    response
  end

  protected

  def parse_data(extracted_file)
    AssembleeNationaleData::ExtractedFileParserService.new(extracted_file).call
  end

  def replace?
    extracted_file2.updated_at > extracted_file1.updated_at
  end

  def response
    @response ||= OpenStruct.new({
                                   replace?: replace?,
                                   data: (replace?) ? extracted_file2_data : nil
                                 })
  end

  def extracted_file1_data
    @extracted_file1_data ||= parse_data(extracted_file1)
  end

  def extracted_file2_data
    @extracted_file2_data ||= parse_data(extracted_file2)
  end
end
