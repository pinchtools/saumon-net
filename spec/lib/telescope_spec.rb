# spec/lib/telescope_spec.rb
require 'rails_helper'

RSpec.describe Telescope do
  let(:context) { { user_id: 1 } }
  let(:enriched_context) do
    hash_including(
      user_id: context[:user_id],
      environment: kind_of(String),
      timestamp: kind_of(Integer),
      process_id: kind_of(Integer)
    )
  end

  describe '.configure' do
    it 'yields configuration instance' do
      expect { |b| described_class.configure(&b) }.to yield_with_args(described_class::Configuration)
    end
  end

  describe '.capture_error' do
    let(:error) { StandardError.new('test error') }

    it 'dispatches error through dispatcher' do
      expect(described_class::Dispatcher).to receive(:dispatch).with(:error, error, enriched_context)
      described_class.capture_error(error, context)
    end
  end

  describe '.log' do
    let(:message) { "Something interesting happened" }

    it 'dispatches the log message through dispatcher' do
      expect(described_class::Dispatcher).to receive(:dispatch).with(:log, message, enriched_context)
      described_class.log(message, context)
    end
  end

  describe '.trace' do
    let(:trace_name) { 'test.trace' }
    let(:context) { { user_id: 1 } }

    context 'with a block' do
      it 'dispatches trace through dispatcher with block' do
        expect(described_class::Dispatcher).to receive(:dispatch)
                                                 .with(:trace, trace_name, enriched_context)
                                                 .and_yield

        expect { |b| described_class.trace(trace_name, context, &b) }.to yield_control
      end
    end

    context 'without a block' do
      it 'dispatches trace through dispatcher without block' do
        expect(described_class::Dispatcher).to receive(:dispatch)
                                                 .with(:trace, trace_name, enriched_context)

        described_class.trace(trace_name, context)
      end
    end
  end
end
