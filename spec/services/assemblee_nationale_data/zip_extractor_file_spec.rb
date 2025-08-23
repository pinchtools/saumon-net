require 'rails_helper'

RSpec.describe AssembleeNationaleData::ZipExtractorService do
  subject(:service) { described_class.new(attachment) }

  let(:is_attached) { true }
  let(:filename) { zip_filename }
  let(:attachment_id) { 123 }
  let(:attachment) do
    double('ActiveStorage::Attached::One',
                    attached?: is_attached,
                    blob: blob,
                    filename: filename,
                    id: attachment_id,
                    record: record)
  end
  let(:blob) { instance_double('ActiveStorage::Blob', content_type: content_type) }
  let(:record) { instance_double('Download', dataset_code: dataset_code, extracted_files: extracted_files_relation) }
  let(:extracted_files_relation) { instance_double('ActiveRecord::Relation') }
  let(:extracted_file) { instance_double('ExtractedFile', file: extracted_file_attachment) }
  let(:extracted_file_attachment) { instance_double('ActiveStorage::Attached::One') }
  let(:dataset_code) { 'AOCUR' }
  let(:zip_filename) { 'test_archive.zip' }
  let(:content_type) { 'application/zip' }
  let(:temp_file) { instance_double('Tempfile', path: '/tmp/temp_file.zip', binmode: nil, rewind: nil) }
  let(:zip_file) { instance_double('Zip::File') }
  let(:is_directory) { false }
  let(:zip_entry) { instance_double('Zip::Entry', name: entry_name, directory?: is_directory, get_input_stream: input_stream) }
  let(:input_stream) { instance_double('Zip::InputStream', read: file_content) }
  let(:entry_name) { 'pays/deputy.json' }
  let(:file_content) { '{"name": "John Doe"}' }
  let(:extracted_files_count) { 1 }

  before do
    allow(blob).to receive(:download).and_yield(file_content)
    allow(Telescope).to receive(:capture_error)
  end

  describe '#initialize' do
    it 'sets the attachment instance variable' do
      expect(service.attachment).to eq(attachment)
    end
  end

  describe '#call' do
    context 'when attachment is not provided' do
      let(:attachment) { nil }

      it 'returns failure with appropriate message' do
        result = service.call

        expect(result.success?).to be false
        expect(result.error_message).to eq('No attachment provided')
      end
    end

    context 'when attachment is not attached' do
      let(:is_attached) { false }

      it 'returns failure with appropriate message' do
        result = service.call

        expect(result.success?).to be false
        expect(result.error_message).to eq('No attachment provided')
      end
    end

    context 'when file is not a zip' do
      let(:content_type) { 'text/plain' }
      let(:zip_filename) { 'document.txt' }

      it 'returns failure with appropriate message' do
        result = service.call

        expect(result.success?).to be false
        expect(result.error_message).to eq('File is not a zip archive')
      end
    end

    context 'when file is a valid zip' do
      before do
        allow(service).to receive(:create_temp_zip_file).and_return(temp_file)
        allow(service).to receive(:download_blob_to_temp_file)
        allow(service).to receive(:cleanup_temp_file)
        allow(Zip::File).to receive(:open).with(temp_file.path).and_yield(zip_file)
        allow(zip_file).to receive(:each).and_yield(zip_entry)
        allow(service).to receive(:should_ignore_file?).and_return(false)
        allow(service).to receive(:extract_and_attach_entry).and_return(extracted_file)
      end

      it 'successfully extracts files and returns success' do
        result = service.call

        expect(result.success?).to be true
        expect(result.data[:extracted_files_count]).to eq(extracted_files_count)
        expect(service).to have_received(:cleanup_temp_file).with(temp_file)
      end

      context 'when zip entry is a directory' do
        let(:is_directory) { true }

        it 'skips directory entries' do
          service.call

          expect(service).not_to have_received(:extract_and_attach_entry)
        end
      end

      context 'when file should be ignored' do
        before do
          allow(service).to receive(:should_ignore_file?).and_return(true)
        end

        it 'skips ignored files' do
          service.call

          expect(service).not_to have_received(:extract_and_attach_entry)
        end
      end

      context 'when Zip::Error occurs' do
        let(:zip_error) { Zip::Error.new('Invalid zip format') }

        before do
          allow(Zip::File).to receive(:open).and_raise(zip_error)
        end

        it 'captures error and returns failure' do
          result = service.call

          expect(Telescope).to have_received(:capture_error).with(
            zip_error,
            context: { attachment_id: attachment_id }
          )
          expect(result.success?).to be false
          expect(result.error_message).to eq('Failed to extract zip file: Invalid zip format')
        end
      end

      context 'when unexpected error occurs' do
        let(:standard_error) { StandardError.new('Unexpected issue') }

        before do
          allow(service).to receive(:download_blob_to_temp_file).and_raise(standard_error)
        end

        it 'captures error and returns failure' do
          result = service.call

          expect(Telescope).to have_received(:capture_error).with(
            standard_error,
            context: { attachment_id: attachment_id }
          )
          expect(result.success?).to be false
          expect(result.error_message).to eq('Unexpected error during extraction: Unexpected issue')
        end
      end
    end
  end

  describe 'private methods' do
    describe '#zip_file?' do
      context 'with zip content type' do
        let(:content_type) { 'application/zip' }

        it { expect(service.send(:zip_file?)).to be true }
      end

      context 'with zip filename extension' do
        let(:content_type) { 'application/octet-stream' }
        let(:zip_filename) { 'archive.ZIP' }

        it 'returns true for uppercase extension' do
          expect(service.send(:zip_file?)).to be true
        end
      end

      context 'with non-zip file' do
        let(:content_type) { 'text/plain' }
        let(:zip_filename) { 'document.txt' }

        it { expect(service.send(:zip_file?)).to be false }
      end
    end

    describe '#create_temp_zip_file' do
      it 'creates a temporary file with correct naming' do
        allow(Tempfile).to receive(:new).with([ 'active_storage_unzip', '.zip' ]).and_return(temp_file)

        result = service.send(:create_temp_zip_file)

        expect(result).to eq(temp_file)
        expect(Tempfile).to have_received(:new).with([ 'active_storage_unzip', '.zip' ])
      end
    end

    describe '#download_blob_to_temp_file' do
      before do
        allow(temp_file).to receive(:write)
      end

      it 'downloads blob content to temp file' do
        service.send(:download_blob_to_temp_file, temp_file)

        expect(temp_file).to have_received(:binmode)
        expect(temp_file).to have_received(:write).with(file_content)
        expect(temp_file).to have_received(:rewind)
        expect(blob).to have_received(:download)
      end
    end

    describe '#create_extracted_file' do
      before do
        allow(extracted_files_relation).to receive(:create!).with(path: entry_name).and_return(extracted_file)
      end

      it 'creates extracted file with correct path' do
        result = service.send(:create_extracted_file, zip_entry)

        expect(result).to eq(extracted_file)
        expect(extracted_files_relation).to have_received(:create!).with(path: entry_name)
      end
    end

    describe '#extract_and_attach_entry' do
      let(:string_io) { double('StringIO') }
      let(:basename) { 'deputy.json' }
      let(:mime_type) { 'application/json' }

      before do
        allow(StringIO).to receive(:new).with(file_content).and_return(string_io)
        allow(Marcel::MimeType).to receive(:for).with(entry_name).and_return(mime_type)
        allow(string_io).to receive(:define_singleton_method).twice
        allow(string_io).to receive(:content_type).and_return(mime_type)
        allow(File).to receive(:basename).with(entry_name).and_return(basename)
        allow(service).to receive(:create_extracted_file).with(zip_entry).and_return(extracted_file)
        allow(extracted_file_attachment).to receive(:attach)
      end

      it 'extracts entry and attaches file' do
        result = service.send(:extract_and_attach_entry, zip_entry)

        expect(StringIO).to have_received(:new).with(file_content)
        expect(extracted_file_attachment).to have_received(:attach).with(
          io: string_io,
          filename: basename,
          content_type: mime_type
        )
        expect(result).to eq(extracted_file)
      end
    end

    describe '#should_ignore_file?' do
      let(:scraper_config) { { 'dirs' => whitelisted_dirs } }
      let(:whitelisted_dirs) { [ 'pays', 'votes' ] }

      before do
        allow(service).to receive(:scraper_configuration).and_return(scraper_config)
      end

      context 'when whitelisted directories are empty' do
        let(:whitelisted_dirs) { [] }

        it { expect(service.send(:should_ignore_file?, zip_entry)).to be false }
      end

      context 'when file is in whitelisted directory' do
        let(:entry_name) { 'pays/deputy.json' }

        it { expect(service.send(:should_ignore_file?, zip_entry)).to be false }
      end

      context 'when file is not in whitelisted directory' do
        let(:entry_name) { 'other/file.json' }

        it { expect(service.send(:should_ignore_file?, zip_entry)).to be true }
      end
    end

    describe '#cleanup_temp_file' do
      before do
        allow(temp_file).to receive(:close)
        allow(temp_file).to receive(:unlink)
      end

      context 'when temp file exists' do
        it 'closes and unlinks the file' do
          service.send(:cleanup_temp_file, temp_file)

          expect(temp_file).to have_received(:close)
          expect(temp_file).to have_received(:unlink)
        end
      end

      context 'when temp file is nil' do
        it 'returns without error' do
          expect { service.send(:cleanup_temp_file, nil) }.not_to raise_error
        end
      end

      context 'when cleanup fails' do
        let(:cleanup_error) { StandardError.new('Cleanup failed') }

        before do
          allow(temp_file).to receive(:close).and_raise(cleanup_error)
        end

        it 'captures error with Telescope' do
          service.send(:cleanup_temp_file, temp_file)

          expect(Telescope).to have_received(:capture_error).with(
            cleanup_error,
            context: { message: 'Failed to cleanup temp file' }
          )
        end
      end
    end

    describe '#scraper_configuration' do
      let(:flattened_config) { { dataset_code => { 'dirs' => [ 'pays' ] } } }

      before do
        allow(AssembleeNationaleData::Configurable).to receive(:flattened_scraper_config_file).and_return(flattened_config)
      end

      it 'memoizes scraper configuration for dataset code' do
        expect(service.send(:scraper_configuration)).to eq(flattened_config[dataset_code])
        expect(AssembleeNationaleData::Configurable).to have_received(:flattened_scraper_config_file).once

        # Call again to test memoization
        service.send(:scraper_configuration)
        expect(AssembleeNationaleData::Configurable).to have_received(:flattened_scraper_config_file).once
      end
    end
  end

  describe '#success' do
    let(:data) { { extracted_files_count: extracted_files_count } }

    it 'returns successful OpenStruct with data' do
      result = service.send(:success, data)

      expect(result).to be_a(OpenStruct)
      expect(result.success?).to be true
      expect(result.failure?).to be false
      expect(result.data).to eq(data)
      expect(result.error_message).to be_nil
    end

    context 'without data parameter' do
      it 'returns success with empty data hash' do
        result = service.send(:success)

        expect(result.data).to eq({})
      end
    end
  end

  describe '#failure' do
    let(:error_message) { 'Test failure message' }

    it 'returns failure OpenStruct with message' do
      result = service.send(:failure, error_message)

      expect(result).to be_a(OpenStruct)
      expect(result.success?).to be false
      expect(result.failure?).to be true
      expect(result.data).to be_nil
      expect(result.error_message).to eq(error_message)
    end
  end
end
