require 'rails_helper'

RSpec.describe AssembleeNationaleData::DownloadedResourceProcessorService do
  subject(:service) { described_class.new(download) }

  let(:download_present) { true }
  let(:file_attached) { true }
  let(:download) { instance_double('Download', present?: download_present, file: file) }
  let(:file) { instance_double('ActiveStorage::Attachement', attached?: file_attached, blob: blob) }
  let(:blob) { instance_double('ActiveStorage::Blob', content_type: content_type) }
  let(:zip_extractor_service) { instance_double('AssembleeNationaleData::ZipExtractorService') }
  let(:content_type) { 'application/zip' }
  let(:success_message) { nil }
  let(:error_message) { 'test error' }

  describe '#initialize' do
    it 'sets the download instance variable' do
      expect(service.instance_variable_get(:@download)).to eq(download)
    end
  end

  describe '#call' do
    context 'when validation fails' do
      before do
        allow(service).to receive(:validate).and_return(service.failure(error_message))
      end

      it 'returns validation failure without processing' do
        result = service.call

        expect(result.success?).to be false
        expect(result.error_message).to eq(error_message)
        expect(AssembleeNationaleData::ZipExtractorService).not_to receive(:new)
      end
    end

    context 'when validation passes' do
      before do
        allow(service).to receive(:validate).and_return(service.success)
      end

      context 'with zip file' do
        let(:process_result) { service.success }

        before do
          allow(AssembleeNationaleData::ZipExtractorService).to receive(:new).with(file).and_return(zip_extractor_service)
          allow(zip_extractor_service).to receive(:call).and_return(process_result)
        end

        context 'when processing succeeds' do
          it 'processes the zip file and returns success' do
            result = service.call

            expect(AssembleeNationaleData::ZipExtractorService).to have_received(:new).with(file)
            expect(zip_extractor_service).to have_received(:call)
            expect(result.success?).to be true
            expect(result.error_message).to be_nil
          end
        end

        context 'when processing fails' do
          let(:process_result) { service.failure('processing failed') }

          it 'returns failure with error message' do
            result = service.call

            expect(result.success?).to be false
            expect(result.error_message).to eq('failed to process file')
          end
        end
      end

      context 'with unsupported file type' do
        let(:content_type) { 'text/plain' }

        it 'returns failure for unsupported content type' do
          result = service.call

          expect(result.success?).to be false
          expect(result.error_message).to eq('failed to process file')
          expect(AssembleeNationaleData::ZipExtractorService).not_to receive(:new)
        end
      end
    end
  end

  describe '#validate' do
    context 'when download is not present' do
      let(:download_present) { false }

      it 'returns failure with missing parameters message' do
        result = service.validate

        expect(result.success?).to be false
        expect(result.error_message).to eq('missing parameters')
      end
    end

    context 'when file is not attached' do
      let(:file_attached) { false }

      it 'returns failure with no file attached message' do
        result = service.validate

        expect(result.success?).to be false
        expect(result.error_message).to eq('no file attached')
      end
    end

    context 'when download is present and file is attached' do
      it { expect(service.validate).to be true }
    end
  end

  describe '#success' do
    it 'returns successful OpenStruct' do
      result = service.success

      expect(result).to be_a(OpenStruct)
      expect(result.success?).to be true
      expect(result.error_message).to be_nil
    end
  end

  describe '#failure' do
    let(:message) { 'test failure message' }

    it 'returns failure OpenStruct with message' do
      result = service.failure(message)

      expect(result).to be_a(OpenStruct)
      expect(result.success?).to be false
      expect(result.error_message).to eq(message)
    end
  end
end
