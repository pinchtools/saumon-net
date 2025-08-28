require 'rails_helper'

RSpec.describe AssembleeNationaleData::SourceSolverFactory do
  describe ".for" do
    context "with acteur source type" do
      let(:source_type) { "acteur" }

      it "returns an Actor source solver instance" do
        result = described_class.for(source_type)

        expect(result).to be_an_instance_of(AssembleeNationaleData::SourceSolver::Actor)
      end
    end

    context "with unknown source type" do
      let(:source_type) { "unknown_type" }

      it "returns nil" do
        result = described_class.for(source_type)

        expect(result).to be_an_instance_of(AssembleeNationaleData::SourceSolver::Default)
      end
    end
  end
end
