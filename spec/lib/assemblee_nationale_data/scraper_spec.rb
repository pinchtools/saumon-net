require 'rails_helper'

RSpec.describe AssembleeNationaleData::Scraper do
  let(:scraper) { described_class.new }
  let(:source) { create(:source, code: 'ANOD') }
  let(:headers) do
    {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
  end
  let(:mock_config) do
    {
      'DATASET_TYPE' => {
        'DATASET_CODE' => {
          'url' => '/test/path',
          'code' => 'test_code'
        }
      }
    }
  end
  let(:env_domain) { 'http://test.example.com' }

  before do
    AssembleeNationaleData.base_url = env_domain
    allow(YAML).to receive(:load_file).and_return(mock_config)
    allow(Source).to receive(:find_by_code!).with(source.code).and_return(source)
  end

  describe '#initialize' do
    it 'sets up headers and loads configuration' do
      expect(scraper.instance_variable_get(:@headers)).to eq(headers)
      expect(scraper.instance_variable_get(:@config_file)).to eq(mock_config)
    end

    it 'finds the correct source' do
      expect(scraper.instance_variable_get(:@source)).to eq(source)
    end
  end

  describe '#fetch_dataset' do
    let(:dataset_type) { 'DATASET_TYPE' }
    let(:dataset_code) { 'DATASET_CODE' }
    let(:html_response) do
      <<~HTML
        <html>
          <body>
            <a href="test_code.json">Download JSON</a>
          </body>
        </html>
      HTML
    end
    let(:json_content) { '{"data": "test"}' }

    before do
      stub_request(:get, "#{AssembleeNationaleData.base_url}/test/path")
        .to_return(status: 200, body: html_response)

      stub_request(:get, "#{AssembleeNationaleData.base_url}/test_code.json")
        .to_return(
          status: 200,
          body: json_content,
          headers: { 'content-type' => 'application/json' }
        )
    end

    it 'successfully fetches and saves dataset' do
      download = scraper.fetch_dataset(dataset_type, dataset_code)
      expect(download).to be_a(Download)
      expect(download.name).to eq('test_code.json')
      expect(download.fingerprint).to eq(
                                        Digest::MD5.hexdigest("#{dataset_code}#{AssembleeNationaleData.base_url}/test_code.json")
                                      )
    end

    context 'when dataset configuration is missing' do
      let(:dataset_type) { 'nonexistent' }

      it 'returns nil' do
        expect(scraper.fetch_dataset(dataset_type, dataset_code)).to be_nil
      end
    end

    context 'when network request fails' do
      before do
        stub_request(:get, "#{AssembleeNationaleData.base_url}/test/path")
          .to_return(status: 500)
      end

      it 'raises NetworkError' do
        expect { scraper.fetch_dataset(dataset_type, dataset_code) }
          .to raise_error(described_class::NetworkError, "Failed to fetch data: 500")
      end

      it 'reports error to Telescope' do
        expect(Telescope).to receive(:capture_error).with(
          instance_of(described_class::NetworkError),
          instance_of(Hash)
        )

        expect { scraper.fetch_dataset(dataset_type, dataset_code) }
          .to raise_error(described_class::NetworkError)
      end
    end

    context 'when no download link is found' do
      let(:html_response) { '<html><body></body></html>' }

      it 'returns nil' do
        expect(scraper.fetch_dataset(dataset_type, dataset_code)).to be_nil
      end

      it 'reports error to Telescope' do
        expect(Telescope).to receive(:capture_error).with(
          instance_of(StandardError),
          instance_of(Hash)
        )

        scraper.fetch_dataset(dataset_type, dataset_code)
      end
    end

    context 'with different file formats' do
      it 'supports zip files' do
        stub_request(:get, "#{AssembleeNationaleData.base_url}test/path")
          .to_return(status: 200, body: '<a href="test_code.json.zip">Download ZIP</a>')

        expect(scraper.fetch_dataset(dataset_type, dataset_code)).to be_a(Download)
      end
    end
  end

  describe 'private methods' do
    describe '#load_dataset_config' do
      it 'returns correct configuration for dataset' do
        config = scraper.send(:load_dataset_config, 'DATASET_TYPE', 'DATASET_CODE')
        expect(config).to eq(mock_config['DATASET_TYPE']['DATASET_CODE'])
      end
    end

    describe '#download_file' do
      let(:url) { 'http://example.com/file.json' }
      let(:response_body) { '{"data": "test"}' }

      before do
        stub_request(:get, url)
          .to_return(status: 200, body: response_body)
      end

      it 'yields the response when successful' do
        expect { |b| scraper.send(:download_file, url, &b) }.to yield_with_args(
                                                                  having_attributes(body: response_body)
                                                                )
      end

      it 'raises error when no block given' do
        expect { scraper.send(:download_file, url) }
          .to raise_error(StandardError, "Expect a block to be given")
      end

      context 'when request fails' do
        before do
          stub_request(:get, url).to_return(status: 404)
        end

        it 'raises NetworkError' do
          expect { scraper.send(:download_file, url) { } }
            .to raise_error(described_class::NetworkError, /Failed to download file/)
        end

        it 'reports error to Telescope' do
          expect(Telescope).to receive(:capture_error).with(
            instance_of(described_class::NetworkError),
            instance_of(Hash)
          )

          expect { scraper.send(:download_file, url) { } }
            .to raise_error(described_class::NetworkError)
        end
      end
    end
  end
end
