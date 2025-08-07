require 'rails_helper'

RSpec.describe Telescope::Adapters::Logger do
  let(:rails_logger) { instance_double('ActiveSupport::Logger') }

  before do
    allow(Rails).to receive(:logger).and_return(rails_logger)
  end

  describe '.send_error' do
    let(:error) { StandardError.new('test error') }
    let(:context) { { user_id: 1, environment: 'test' } }

    before do
      allow(error).to receive(:backtrace).and_return([ 'line1', 'line2' ])
    end

    it 'logs error with full details' do
      expect(rails_logger).to receive(:error).with('[Telescope] StandardError: test error')
      expect(rails_logger).to receive(:error).with(context.to_json)
      expect(rails_logger).to receive(:error).with("line1\nline2")

      described_class.send_error(error, context)
    end
  end

  describe '.send_trace' do
    let(:trace_name) { 'test_operation' }
    let(:context) { { user_id: 1, action: 'create' } }

    context 'without block' do
      it 'logs trace start with context' do
        expect(rails_logger).to receive(:info).with('[Telescope] test_operation started')
        expect(rails_logger).to receive(:info).with(context.to_json)

        described_class.send_trace(trace_name, context)
      end
    end

    context 'with block' do
      before do
        allow(Time).to receive(:current).and_return(
          Time.new(2024, 1, 1, 12, 0, 0),
          Time.new(2024, 1, 1, 12, 0, 2)
        )
      end

      it 'logs start, executes block, and logs completion with duration' do
        expect(rails_logger).to receive(:info).with('[Telescope] test_operation started')
        expect(rails_logger).to receive(:info).with(context.to_json)
        expect(rails_logger).to receive(:info).with('[Telescope] test_operation completed in 2.0s')

        block_executed = false
        described_class.send_trace(trace_name, context) do
          block_executed = true
        end

        expect(block_executed).to be true
      end

      it 'ensures completion is logged even if block raises error' do
        expect(rails_logger).to receive(:info).with('[Telescope] test_operation started')
        expect(rails_logger).to receive(:info).with(context.to_json)
        expect(rails_logger).to receive(:info).with('[Telescope] test_operation completed in 2.0s')

        expect {
          described_class.send_trace(trace_name, context) do
            raise StandardError, 'test error'
          end
        }.to raise_error(StandardError, 'test error')
      end
    end
  end
end
