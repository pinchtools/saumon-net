require 'rails_helper'

RSpec.describe AssembleeNationaleData::Scraper do
  let(:source_type) { 'ANOD' }
  let(:scraper) { described_class.new }
  let(:source) { create(:source, code: source_type) }
  let(:headers) do
    {
      "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
    }
  end
  let(:mock_config) do
    {
      source_type => {
        'DATASET_TYPE' => {
          'DATASET_CODE' => {
            'url' => '/test/path',
            'code' => 'test_code'
          }
        }
      }
    }
  end
  let(:env_domain) { 'http://test.example.com' }

  before do
    AssembleeNationaleData.base_url = env_domain
    allow(AssembleeNationaleData::Configurable).to receive(:scraper_config_file).and_return(mock_config)
    allow(Source).to receive(:find_by_code!).with(source.code).and_return(source)
  end

  describe '#initialize' do
    it 'sets up headers and loads configuration' do
      expect(scraper.instance_variable_get(:@headers)).to eq(headers)
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
    let(:download) { create(:download, source: source, name: 'test_code.json') }
    let(:download_processor_service) { instance_double(DownloadProcessorService) }

    before do
      # Mock the HTML page request (this stays the same)
      stub_request(:get, "#{AssembleeNationaleData.base_url}/test/path")
        .to_return(status: 200, body: html_response)

      # Mock the DownloadProcessorService instead of the actual file download
      allow(DownloadProcessorService).to receive(:new).and_return(download_processor_service)
      allow(download_processor_service).to receive(:call).and_return(download)
    end

    it 'successfully fetches and saves dataset' do
      result = scraper.fetch_dataset(dataset_type, dataset_code)

      expect(DownloadProcessorService).to have_received(:new).with(
        uri: URI.parse("#{AssembleeNationaleData.base_url}/test_code.json"),
        dataset_code: dataset_code,
        source: source
      )
      expect(download_processor_service).to have_received(:call)
      expect(result).to eq(download)
    end

    context 'when dataset configuration is missing' do
      let(:dataset_type) { 'nonexistent' }

      it 'returns nil' do
        expect(scraper.fetch_dataset(dataset_type, dataset_code)).to be_nil
      end

      it 'does not call DownloadProcessorService' do
        scraper.fetch_dataset(dataset_type, dataset_code)
        expect(DownloadProcessorService).not_to have_received(:new)
      end
    end

    context 'when network request fails' do
      before do
        stub_request(:get, "#{AssembleeNationaleData.base_url}/test/path")
          .to_return(status: 500)
      end

      it 'raises NetworkError' do
        expect { scraper.fetch_dataset(dataset_type, dataset_code) }
          .to raise_error(Telescope::NetworkError, "Failed to fetch data: 500")
      end

      it 'reports error to Telescope' do
        expect(Telescope).to receive(:capture_error).with(
          instance_of(Telescope::NetworkError),
          instance_of(Hash)
        )

        expect { scraper.fetch_dataset(dataset_type, dataset_code) }
          .to raise_error(Telescope::NetworkError)
      end

      it 'does not call DownloadProcessorService' do
        expect { scraper.fetch_dataset(dataset_type, dataset_code) }
          .to raise_error(Telescope::NetworkError)
        expect(DownloadProcessorService).not_to have_received(:new)
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

      it 'does not call DownloadProcessorService' do
        scraper.fetch_dataset(dataset_type, dataset_code)
        expect(DownloadProcessorService).not_to have_received(:new)
      end
    end

    context 'when DownloadProcessorService fails' do
      before do
        allow(download_processor_service).to receive(:call)
                                               .and_raise(Telescope::NetworkError.new("Download failed"))
      end

      it 'propagates the service error' do
        expect { scraper.fetch_dataset(dataset_type, dataset_code) }
          .to raise_error(Telescope::NetworkError, "Download failed")
      end
    end

    context 'with different file formats' do
      let(:html_response) { '<a href="test_code.json.zip">Download ZIP</a>' }

      it 'supports zip files' do
        result = scraper.fetch_dataset(dataset_type, dataset_code)

        expect(DownloadProcessorService).to have_received(:new).with(
          uri: URI.parse("#{AssembleeNationaleData.base_url}/test_code.json.zip"),
          dataset_code: dataset_code,
          source: source
        )
        expect(result).to eq(download)
      end
    end

    context 'with relative URLs' do
      let(:html_response) { '<a href="/relative/test_code.json">Download</a>' }

      it 'converts relative URLs to absolute' do
        scraper.fetch_dataset(dataset_type, dataset_code)

        expect(DownloadProcessorService).to have_received(:new).with(
          uri: URI.parse("#{AssembleeNationaleData.base_url}/relative/test_code.json"),
          dataset_code: dataset_code,
          source: source
        )
      end
    end
  end

  describe 'private methods' do
    describe '#load_dataset_config' do
      it 'returns correct configuration for dataset' do
        config = scraper.send(:load_dataset_config, 'DATASET_TYPE', 'DATASET_CODE')
        expect(config).to eq(mock_config[described_class::SOURCE_TYPE]['DATASET_TYPE']['DATASET_CODE'])
      end
    end

    describe '#save_file' do
      let(:uri) { URI.parse('http://example.com/test_file.json') }
      let(:dataset_code) { 'test_dataset' }
      let(:download_processor_service) { instance_double(DownloadProcessorService) }
      let(:download) { create(:download, source: source) }

      before do
        allow(DownloadProcessorService).to receive(:new)
                                             .with(uri: uri, dataset_code: dataset_code, source: source)
                                             .and_return(download_processor_service)
        allow(download_processor_service).to receive(:call).and_return(download)
      end

      it 'delegates to DownloadProcessorService with correct parameters' do
        result = scraper.send(:save_file, uri, dataset_code)

        expect(DownloadProcessorService).to have_received(:new).with(
          uri: uri,
          dataset_code: dataset_code,
          source: source
        )
        expect(download_processor_service).to have_received(:call)
        expect(result).to eq(download)
      end

      context 'when DownloadProcessorService raises an error' do
        before do
          allow(download_processor_service).to receive(:call)
                                                 .and_raise(Telescope::NetworkError.new("Network failed"))
        end

        it 'propagates the error' do
          expect { scraper.send(:save_file, uri, dataset_code) }
            .to raise_error(Telescope::NetworkError, "Network failed")
        end
      end
    end
  end
end
