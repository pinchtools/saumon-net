require 'rails_helper'


RSpec.describe AssembleeNationaleData::Configurable, :memoization_cleanup do
  let(:sample_config) do
    {
      "ANOD" => {
        "deputes" => {
          "current" => {
            "url" => "deputes/current",
            "code" => "deputes_current"
          }
        },
        "votes" => {
          "2022" => {
            "url" => "votes/2022",
            "code" => "votes_2022"
          }
        }
      }
    }
  end

  describe ".base_url" do
    let(:base_url) { "https://api.example.com" }
    before do
      allow(AssembleeNationaleData).to receive(:base_url).and_return(base_url)
    end

    context "when AssembleeNationaleData.base_url returns a value" do
      it { expect(described_class.base_url).to eq(base_url) }
    end

    context "when AssembleeNationaleData.base_url returns nil" do
      let(:base_url) { nil }
      it { expect(described_class.base_url).to be_nil }
    end
  end

  describe ".scraper_config_file" do
    let(:config_path) { Rails.root.join("config", "lib", "assemblee_nationale_data", "scraper.yml") }

    context "when config file exists and is valid" do
      before do
        allow(YAML).to receive(:load_file).with(config_path).and_return(sample_config)
      end

      it "loads and returns the YAML config" do
        expect(described_class.scraper_config_file).to eq(sample_config)
      end
    end

    context "when config file doesn't exist" do
      before do
        allow(YAML).to receive(:load_file).with(config_path).and_raise(Errno::ENOENT)
      end

      it "raises an error" do
        expect { described_class.scraper_config_file }.to raise_error(Errno::ENOENT)
      end
    end
  end

  describe ".flattened_scraper_config_file" do
    before do
      allow(described_class).to receive(:scraper_config_file).and_return(sample_config)
    end

    it "flattens the nested configuration structure" do
      result = described_class.flattened_scraper_config_file

      expect(result).to include(
                          "current" => {
                            "url" => "deputes/current",
                            "code" => "deputes_current",
                            "source_code" => "ANOD",
                            "entity_type" => "deputes"
                          },
                          "2022" => {
                            "url" => "votes/2022",
                            "code" => "votes_2022",
                            "source_code" => "ANOD",
                            "entity_type" => "votes"
                          }
                        )
    end

    it "preserves original attributes and adds metadata" do
      result = described_class.flattened_scraper_config_file

      current_config = result["current"]
      expect(current_config).to have_key("url")
      expect(current_config).to have_key("code")
      expect(current_config).to have_key("source_code")
      expect(current_config).to have_key("entity_type")
    end

    it "handles empty configuration gracefully" do
      allow(described_class).to receive(:scraper_config_file).and_return({})

      expect(described_class.flattened_scraper_config_file).to eq({})
    end
  end
end
