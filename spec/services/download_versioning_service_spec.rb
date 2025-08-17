require 'rails_helper'

RSpec.describe DownloadVersioningService do
  let(:name) { 'test_file.json' }
  let(:source) { create(:source) }
  let(:fingerprint) { 'abc123' }
  let(:dataset_code) { 'AN_VOTE' }
  let(:service) do
    described_class.new(name: name,
                        fingerprint: fingerprint,
                        dataset_code: dataset_code,
                        source: source)
  end

  describe '#initialize' do
    it 'sets fingerprint and source' do
      expect(service.fingerprint).to eq(fingerprint)
      expect(service.dataset_code).to eq(dataset_code)
      expect(service.source).to eq(source)
    end
  end

  describe '#valid?' do
    context 'all conditions are met' do
      it { expect(service).to be_valid }
    end

    context 'source is nil' do
      let(:source) { nil }
      it { expect(service).not_to be_valid }
    end
  end

  describe '#call' do
    let(:current) { false }
    let(:existing_name) { name }
    let(:existing_source) { source }
    let(:existing_fingerprint) { fingerprint }
    let(:existing_dataset_code) { dataset_code }
    let(:existing_download) do
      create(:download,
             name: existing_name,
             source: existing_source,
             fingerprint: existing_fingerprint,
             dataset_code: existing_dataset_code,
             version: 2,
             current: current
      )
    end

    context 'when service is valid' do
      context 'with no existing downloads' do
        it 'creates a new download with version 1' do
          download = service.call

          expect(download).to be_persisted
          expect(download.fingerprint).to eq(fingerprint)
          expect(download.dataset_code).to eq(dataset_code)
          expect(download.version).to eq(1)
          expect(download.current).to be true
          expect(download.source).to eq(source)
        end
      end

      context 'with existing non-current downloads' do
        before { existing_download }

        it 'creates new download with incremented version' do
          download = service.call

          expect(download).to be_persisted
          expect(download.version).to eq(existing_download.version + 1)
          expect(download.current).to be true
        end

        it 'does not affect existing non-current downloads' do
          service.call
          expect(existing_download.reload.current).to be false
        end
      end

      context 'with existing current download' do
        let(:current) { true }
        before { existing_download }

        it 'sets existing current download to non-current' do
          service.call
          expect(existing_download.reload.current).to be false
        end

        it 'creates new current download with incremented version' do
          download = service.call

          expect(download.version).to eq(existing_download.version + 1)
          expect(download.current).to be true
        end

        context 'the creation failed' do
          before do
            allow(source.downloads).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Download.new))
          end

          it 'rolls back all changes when an error occurs' do
            expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)

            expect(existing_download.reload.current).to be true
            expect(Download.count).to eq(1)
          end
        end
      end

      context 'with multiple existing downloads with same fingerprint' do
        let!(:download1) { create(:download, source: source, fingerprint: fingerprint, version: 1, current: false) }
        let!(:download2) { create(:download, source: source, fingerprint: fingerprint, version: 3, current: false) }
        let!(:current_download) { create(:download, source: source, fingerprint: fingerprint, version: 5, current: true) }

        it 'creates new download with version based on maximum existing version' do
          download = service.call

          expect(download.version).to eq(6)
          expect(download.current).to be true
        end

        it 'sets only the current download to non-current' do
          service.call

          expect(download1.reload.current).to be false
          expect(download2.reload.current).to be false
          expect(current_download.reload.current).to be false
        end
      end

      context 'with downloads from different sources' do
        let(:existing_source) { create(:source, name: 'other_source') }
        before { existing_download }

        it 'ignores downloads from other sources' do
          download = service.call

          expect(download.version).to eq(1)
          expect(existing_download.reload.current).to be false
        end
      end

      context 'with downloads with different fingerprints' do
        let(:existing_fingerprint) { 'different123' }
        before { existing_download }

        it 'ignores downloads with different fingerprints' do
          download = service.call

          expect(download.version).to eq(1)
          expect(existing_download.reload.current).to be false
        end
      end
    end

    context 'when service is not valid' do
      let(:source) { nil }

      it 'does not create any downloads' do
        expect { service.call }.not_to change(Download, :count)
      end

      it { expect(service.call).to be_nil }
    end

    context 'when transaction fails' do
      let(:current) { true }
      before { existing_download }

      before do
        allow(source.downloads).to receive(:create!).and_raise(ActiveRecord::RecordInvalid.new(Download.new))
      end

      it 'rolls back the transaction' do
        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
        expect(existing_download.reload.current).to be true
      end

      it 'reports error to Telescope' do
        expect(Telescope).to receive(:capture_error).with(
          instance_of(ActiveRecord::RecordInvalid),
          instance_of(Hash)
        )

        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
      end
    end

    context 'when updating current download fails' do
      let(:current) { true }
      before { existing_download }

      before do
        allow(service).to receive(:current_download).and_return(existing_download)
        allow(existing_download).to receive(:update!).and_raise(ActiveRecord::RecordInvalid.new(existing_download))
      end

      it 'rolls back the transaction' do
        expect { service.call }.to raise_error(ActiveRecord::RecordInvalid)
        expect(Download.where(fingerprint: fingerprint, current: true).count).to eq(1)
      end
    end
  end

  describe 'private methods' do
    describe '#current_download' do
      context 'when current download exists' do
        let!(:current_download) do
          create(:download,
                 source: source,
                 fingerprint: fingerprint,
                 current: true
          )
        end

        it 'returns the current download' do
          expect(service.send(:current_download)).to eq(current_download)
        end

        it 'memoizes the result' do
          expect(source.downloads).to receive(:find_by).once.and_call_original
          2.times { service.send(:current_download) }
        end
      end

      context 'when no current download exists' do
        it 'returns nil' do
          expect(service.send(:current_download)).to be_nil
        end
      end
    end

    describe '#next_version' do
      context 'when no downloads exist' do
        it 'returns 1' do
          expect(service.send(:next_version)).to eq(1)
        end
      end

      context 'when downloads exist' do
        let!(:download1) { create(:download, source: source, fingerprint: fingerprint, version: 1) }
        let!(:download2) { create(:download, source: source, fingerprint: fingerprint, version: 3) }

        it 'returns maximum version + 1' do
          expect(service.send(:next_version)).to eq(4)
        end

        it 'memoizes the result' do
          expect(source.downloads).to receive(:where).once.and_call_original
          2.times { service.send(:next_version) }
        end
      end

      context 'when maximum version is nil' do
        before do
          allow(source.downloads).to receive_messages(where: double(maximum: nil))
        end

        it 'returns 1' do
          expect(service.send(:next_version)).to eq(1)
        end
      end
    end
  end

  describe 'error handling' do
    it 'includes Rescuable module' do
      expect(described_class.included_modules).to include(Telescope::Rescuable)
    end
  end
end
