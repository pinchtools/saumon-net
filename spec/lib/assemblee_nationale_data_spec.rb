RSpec.describe AssembleeNationaleData do
  describe 'configuration' do
    let(:custom_url) { 'https://custom.example.com' }
    let(:env_domain) { 'http://test.example.com' }

    before do
      stub_const('ENV', ENV.to_hash.merge('AN_DATA_DOMAIN' => env_domain))
    end

    after do
      described_class.base_url = ENV['AN_DATA_DOMAIN']
    end

    it 'allows setting base_url' do
      described_class.base_url = custom_url
      expect(described_class.base_url).to eq(custom_url)
    end

    it 'uses ENV["AN_DATA_DOMAIN"] as default base_url' do
      expect(described_class.base_url).to eq(env_domain)
    end
  end

  describe 'error handling' do
    it 'defines a custom Error class' do
      expect(described_class::Error).to be < StandardError
    end
  end
end
