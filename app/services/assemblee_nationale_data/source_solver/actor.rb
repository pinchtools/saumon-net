class AssembleeNationaleData::SourceSolver::Actor < AssembleeNationaleData::SourceSolver::Base
  def compare(extracted_file1, extracted_file2)
    super(extracted_file1, extracted_file2)

    response
  end

  def replace?
    @need_replace ||= extracted_file2_data[:root_data][:mandats].count > extracted_file1_data[:root_data][:mandats].count
  end
end
