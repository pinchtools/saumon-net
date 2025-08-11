require 'rails_helper'

RSpec.describe DownloadProcessorService do
  subject(:service) { described_class.new(uri: uri, dataset_code: dataset_code, source: source) }

  let(:uri) { URI.parse('http://example.com/test_file.json') }
  let(:dataset_code) { 'test_dataset' }
  let(:source) { create(:source, code: 'TEST') }
  let(:fingerprint) { Digest::MD5.hexdigest(dataset_code + uri.to_s) }
  let(:filename) { 'test_file.json' }
  let(:response_body) { '{"data": "test content"}' }
  let(:file_checksum) { Digest::MD5.hexdigest(response_body) }
  let(:http_response) do
    instance_double('HTTParty::Response',
                    success?: true,
                    body: response_body,
                    headers: { 'content-type' => 'application/json' }
    )
  end
  let(:current_resolver_service) { instance_double(CurrentDownloadResolverService) }
  let(:versioning_service) { instance_double(DownloadVersioningService) }
  let(:download) { create(:download, source: source, fingerprint: fingerprint, name: filename) }

  before do
    allow(CurrentDownloadResolverService).to receive(:new)
                                               .with(fingerprint: fingerprint, source: source)
                                               .and_return(current_resolver_service)
    allow(current_resolver_service).to receive(:call).and_return(download)
    allow(HTTParty).to receive(:get).with(uri.to_s, headers: service.send(:download_headers))
                                    .and_yield(http_response).and_return(http_response)
    allow(Telescope).to receive(:log)
  end

  describe '#initialize' do
    it 'sets instance variables correctly' do
      expect(service.uri).to eq(uri)
      expect(service.dataset_code).to eq(dataset_code)
      expect(service.source).to eq(source)
    end
  end

  describe '#call' do
    shared_examples 'successful file attachment' do |attached: true|
      it 'attaches file and saves download' do
        file_attachment = double('file_attachment', attached?: attached)
        allow(download).to receive(:file).and_return(file_attachment)
        allow(file_attachment).to receive(:attach)
        allow(download).to receive(:save!)

        result = service.call

        expect(file_attachment).to have_received(:attach).with(
          io: instance_of(StringIO),
          filename: filename,
          content_type: 'application/json'
        )
        expect(download).to have_received(:save!)
        expect(result).to eq(download)
      end
    end

    context 'when no file is attached' do
      it_behaves_like 'successful file attachment', attached: false

      it 'does not log already downloaded message' do
        allow(download).to receive(:file).and_return(double('file_attachment', attached?: false, attach: true))
        allow(download).to receive(:save!)

        service.call

        expect(Telescope).not_to have_received(:log)
      end
    end

    context 'when file is attached with same checksum' do
      let(:file_attachment) { double('ActiveStorage::Attached', attached?: true, checksum: file_checksum) }

      before do
        allow(download).to receive(:file).and_return(file_attachment)
      end

      it 'logs that file is already downloaded' do
        result = service.call

        expect(Telescope).to have_received(:log).with(
          "File #{uri} is already downloaded",
          instance_of(Hash)
        )
        expect(result).to eq(download)
      end

      it 'does not attach new file' do
        expect(file_attachment).not_to receive(:attach)
        service.call
      end

      it 'returns early without saving' do
        expect(download).not_to receive(:save!)
        service.call
      end
    end

    context 'when file is attached with different checksum' do
      let(:existing_checksum) { 'different_checksum' }
      let(:file_attachment) { double('ActiveStorage::Attached', attached?: true, checksum: existing_checksum) }
      let(:new_download) { create(:download, source: source, fingerprint: fingerprint, name: filename, version: 2) }

      before do
        # simulate that the download versioning service returns a different checksum than the http request
        allow(download).to receive(:file).and_return(file_attachment)

        # and then mock the DownloadVersioningService with the new download as checksum is detectec as !=
        allow(DownloadVersioningService).to receive(:new)
                                              .with(name: download.name, fingerprint: fingerprint, source: source)
                                              .and_return(versioning_service)
        allow(versioning_service).to receive(:call).and_return(new_download)
        allow(new_download).to receive(:file).and_return(double('file_attachment', attach: true))
        allow(new_download).to receive(:save!)
      end

      it 'creates new version and attaches file' do
        service.call

        expect(DownloadVersioningService).to have_received(:new).with(
          name: download.name,
          fingerprint: fingerprint,
          source: source
        )
        expect(versioning_service).to have_received(:call)
        expect(new_download).to have_received(:save!)
      end

      it 'returns new download version' do
        result = service.call
        expect(result).to eq(new_download)
      end
    end

    context 'when HTTP request fails' do
      before do
        allow(http_response).to receive(:success?).and_return(false)
        allow(http_response).to receive(:code).and_return(404)
      end

      it 'raises NetworkError' do
        expect { service.call }
          .to raise_error(Telescope::NetworkError, "Failed to download: 404")
      end
    end

    context 'when service dependencies fail' do
      before do
        allow(download).to receive(:file).and_raise(StandardError.new("Service error"))
        allow(Telescope).to receive(:capture_error)
      end

      it 'captures error with Telescope and re-raises' do
        expect { service.call }.to raise_error(StandardError, "Service error")
        expect(Telescope).to have_received(:capture_error).with(
          instance_of(StandardError),
          hash_including(class: described_class.name)
        )
      end
    end
  end

  describe 'private methods' do
    describe '#fingerprint' do
      it 'generates MD5 hash from dataset_code and uri' do
        expected_fingerprint = Digest::MD5.hexdigest(dataset_code + uri.to_s)
        expect(service.send(:fingerprint)).to eq(expected_fingerprint)
      end

      it 'memoizes the result' do
        expect(Digest::MD5).to receive(:hexdigest).once.and_call_original
        2.times { service.send(:fingerprint) }
      end
    end

    describe '#filename' do
      it 'extracts filename from URI path' do
        expect(service.send(:filename)).to eq('test_file.json')
      end

      context 'with complex path' do
        let(:uri) { URI.parse('http://example.com/path/to/complex_file.xlsx') }

        it 'returns last segment of path' do
          expect(service.send(:filename)).to eq('complex_file.xlsx')
        end
      end
    end

    describe '#resolve_or_create_download' do
      it 'calls CurrentDownloadResolverService with correct parameters' do
        expect(download).to receive(:name=).with(filename)

        result = service.send(:resolve_or_create_download)

        expect(CurrentDownloadResolverService).to have_received(:new).with(
          fingerprint: fingerprint,
          source: source
        )
        expect(result).to eq(download)
      end
    end

    describe '#download_file_content' do
      it 'makes HTTP request with correct headers' do
        result = service.send(:download_file_content)

        expect(HTTParty).to have_received(:get).with(
          uri.to_s,
          headers: service.send(:download_headers)
        )
        expect(result).to eq(http_response)
      end
    end

    describe '#file_needs_update?' do
      let(:file_content) { double('response', body: response_body) }
      let(:file_attachment) { double('ActiveStorage::Attached', attached?: true, checksum: file_checksum) }

      before do
        allow(download).to receive(:file).and_return(file_attachment)
      end

      context 'when checksums match' do
        it 'returns false' do
          result = service.send(:file_needs_update?, download, file_content)
          expect(result).to be false
        end
      end

      context 'when checksums differ' do
        let(:response_body) { 'different content' }

        it 'returns true' do
          allow(download).to receive_message_chain(:file, :checksum).and_return('old_checksum')
          result = service.send(:file_needs_update?, download, file_content)
          expect(result).to be true
        end
      end
    end

    describe '#download_headers' do
      it 'returns correct User-Agent header' do
        headers = service.send(:download_headers)

        expect(headers).to eq({
                                "User-Agent" => "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/91.0.4472.124 Safari/537.36"
                              })
      end
    end
  end
end
