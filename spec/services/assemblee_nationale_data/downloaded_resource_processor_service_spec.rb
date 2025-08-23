require 'rails_helper'

RSpec.describe AssembleeNationaleData::DownloadedResourceProcessorService do
  subject(:service) { described_class.new(download) }

  let(:download_present) { true }
  let(:file_attached) { true }
  let(:download) { instance_double('Download', present?: download_present, file: file) }
  let(:file) { double('ActiveStorage::Attached::One', attached?: file_attached, blob: blob) }
  let(:blob) { instance_double('ActiveStorage::Blob', content_type: content_type) }
  let(:zip_extractor_service) { instance_double('AssembleeNationaleData::ZipExtractorService') }
  let(:content_type) { 'application/zip' }
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
        allow(service).to receive(:validate).and_return(OpenStruct.new(success?: true))
      end

      context 'with zip file' do
        let(:zip_success_result) { OpenStruct.new(success?: true, success: 'zip_success_object') }

        before do
          allow(AssembleeNationaleData::ZipExtractorService).to receive(:new).with(file).and_return(zip_extractor_service)
          allow(zip_extractor_service).to receive(:call).and_return(zip_success_result)
        end

        context 'when processing succeeds' do
          it 'processes the zip file and returns the success object from zip service' do
            result = service.call

            expect(AssembleeNationaleData::ZipExtractorService).to have_received(:new).with(file)
            expect(zip_extractor_service).to have_received(:call)
            expect(result).to eq(zip_success_result)
          end
        end

        context 'when processing fails' do
          let(:zip_failure_result) { OpenStruct.new(success?: false, error_message: 'zip processing failed') }

          before do
            allow(zip_extractor_service).to receive(:call).and_return(zip_failure_result)
          end

          it 'returns failure with generic error message' do
            result = service.call

            expect(result).to eq(zip_failure_result)
          end
        end
      end

      context 'with unsupported file type' do
        let(:content_type) { 'text/plain' }

        it 'returns failure for unsupported content type' do
          result = service.call

          expect(result.success?).to be false
          expect(result.error_message).to eq('unsupported content type')
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
      it { expect(service.validate).to eq(OpenStruct.new(success?: true)) }
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
