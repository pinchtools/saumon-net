class AssembleeNationaleData::SourceSolverFactory
  def self.for(source_type)
    case source_type
    when "acteur"
      AssembleeNationaleData::SourceSolver::Actor.new
    else
      AssembleeNationaleData::SourceSolver::Default.new
    end
  end
end
