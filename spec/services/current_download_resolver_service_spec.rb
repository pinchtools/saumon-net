require 'rails_helper'

RSpec.describe CurrentDownloadResolverService do
  let(:source) { create(:source) }
  let(:fingerprint) { 'abc123' }
  let(:dataset_code) { 'AN_VOTE' }
  let(:service) { described_class.new(fingerprint: fingerprint, dataset_code: dataset_code, source: source) }

  describe '#initialize' do
    it 'sets fingerprint and source' do
      expect(service.fingerprint).to eq(fingerprint)
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

    context 'fingerprint is nil' do
      let(:fingerprint) { nil }
      it { expect(service).not_to be_valid }
    end

    context 'dataset_code is nil' do
      let(:dataset_code) { nil }
      it { expect(service).not_to be_valid }
    end
  end

  describe '#call' do
    let(:current) { false }
    let(:existing_source) { source }
    let(:existing_fingerprint) { fingerprint }
    let(:existing_download) do
      create(:download,
             source: existing_source,
             fingerprint: fingerprint,
             dataset_code: dataset_code,
             version: 2,
             current: current
      )
    end

    context 'when service is valid' do
      context 'with no existing downloads' do
        it 'creates a new download with version 1' do
          download = service.call

          expect(download).to be_new_record
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

          expect(download).to be_new_record
          expect(download.version).to eq(existing_download.version + 1)
          expect(download.current).to be true
        end
      end

      context 'with existing current download' do
        let(:current) { true }
        before { existing_download }

        it 'returns the existing download' do
          expect(service.call).to eq(existing_download)
        end

        it 'does not increment version' do
          download = service.call
          expect(download.version).to be(2)
        end
      end

      context 'with downloads from different sources' do
        let(:existing_source) { create(:source, name: 'other_source') }
        before { existing_download }

        it 'ignores downloads from other sources' do
          expect(service.call).to be_new_record
        end
      end

      context 'with downloads with different fingerprints' do
        let(:existing_fingerprint) { "different123" }
        before { existing_download }

        it 'ignores downloads with different fingerprints' do
          expect(service.call).to be_new_record
        end
      end
    end

    context 'when service is not valid' do
      before do
        allow(service).to receive(:valid?).and_return(false)
      end

      it 'does not create any downloads' do
        expect { service.call }.not_to change(Download, :count)
      end

      it { expect(service.call).to be_nil }
    end
  end
end
