
require 'rails_helper'

RSpec.describe Telescope::Adapters::Sentry do
  let(:scope) { instance_double('Sentry::Scope') }
  let(:transaction) { instance_double('Sentry::Transaction') }
  let(:hub) { class_double('Sentry') }
  let(:error) { class_double('Sentry::Error') }
  let(:context) { { user_id: 1, environment: 'test' } }
  let(:payload) { { duration: 1.5, custom_data: 'value' } }

  before do
    stub_const('Sentry', hub)
    stub_const('Sentry::Error', error)

    allow(hub).to receive(:with_scope).and_yield(scope)
    allow(hub).to receive(:initialized?).and_return(true)
    allow(scope).to receive(:set_tags)
    allow(scope).to receive(:set_extras)
    allow(scope).to receive(:set_user)
    allow(scope).to receive(:set_span)
    allow(transaction).to receive(:set_data)
    allow(transaction).to receive(:set_timestamp)
    allow(transaction).to receive(:set_duration)
    allow(transaction).to receive(:finish)
    allow(hub).to receive(:get_current_scope).and_return(scope)
  end

  describe '.send_error' do
    let(:error) { StandardError.new('test error') }

    context 'when Sentry is configured' do
      before do
        allow(hub).to receive(:capture_exception)
      end

      it 'captures exception with context' do
        expect(hub).to receive(:capture_exception).with(error)
        expect(scope).to receive(:set_extras).with(context)

        described_class.send_error(error, context)
      end

      context 'when Sentry raises an error' do
        before do
          allow(hub).to receive(:capture_exception).and_raise(Sentry::Error, 'Sentry error')
        end

        it 'wraps Sentry errors in AdapterError' do
          expect {
            described_class.send_error(error, context)
          }.to raise_error(
                 Telescope::AdapterError,
                 'Sentry error: Sentry error'
               )
        end
      end
    end

    context 'when Sentry is not configured' do
      before do
        allow(hub).to receive(:initialized?).and_return(false)
      end

      it 'raises AdapterConfigurationError' do
        expect {
          described_class.send_error(error, context)
        }.to raise_error(
               Telescope::AdapterConfigurationError,
               'Sentry is not configured'
             )
      end
    end
  end

  describe '.send_trace' do
    let(:trace_name) { 'test.operation' }

    context 'when Sentry is configured' do
      before do
        allow(hub).to receive(:start_transaction).and_return(transaction)
      end

      it 'creates transaction with correct operation and name' do
        expect(hub).to receive(:start_transaction).with(
          op: 'telescope.trace',
          name: trace_name
        )

        described_class.send_trace(trace_name, payload, context)
      end

      it 'sets transaction as current span' do
        expect(scope).to receive(:set_span).with(transaction)

        described_class.send_trace(trace_name, payload, context)
      end

      it 'sets context data on scope' do
        expect(scope).to receive(:set_extras).with(context)

        described_class.send_trace(trace_name, payload, context)
      end

      it 'sets payload data on transaction' do
        expect(transaction).to receive(:set_data).with('custom_data', 'value')

        described_class.send_trace(trace_name, payload, context)
      end

      context 'when payload includes duration' do
        let(:current_time) { Time.now }

        before do
          allow(Time).to receive(:now).and_return(current_time)
        end

        it 'sets timestamp and duration on transaction' do
          expect(transaction).to receive(:set_timestamp).with(current_time.to_f)
          expect(transaction).to receive(:set_duration).with(payload[:duration])

          described_class.send_trace(trace_name, payload, context)
        end
      end

      it 'finishes the transaction' do
        expect(transaction).to receive(:finish)

        described_class.send_trace(trace_name, payload, context)
      end

      context 'with block' do
        it 'yields transaction to the block' do
          expect { |b| described_class.send_trace(trace_name, payload, context, &b) }
            .to yield_with_args(transaction)
        end

        it 'finishes transaction even if block raises error' do
          expect(transaction).to receive(:finish)

          expect do
            described_class.send_trace(trace_name, payload, context) do |_transaction|
              raise StandardError, 'Block error'
            end
          end.to raise_error(Telescope::AdapterError, 'Sentry trace error: Block error')
        end
      end

      context 'when Sentry raises an error' do
        before do
          allow(hub).to receive(:start_transaction).and_raise(StandardError, 'Sentry trace error')
        end

        it 'wraps Sentry errors in AdapterError' do
          expect do
            described_class.send_trace(trace_name, payload, context)
          end.to raise_error(
                   Telescope::AdapterError,
                   'Sentry trace error: Sentry trace error'
                 )
        end
      end
    end

    context 'when Sentry is not configured' do
      before do
        allow(hub).to receive(:initialized?).and_return(false)
      end

      it 'raises AdapterConfigurationError' do
        expect do
          described_class.send_trace(trace_name, payload, context)
        end.to raise_error(
                 Telescope::AdapterConfigurationError,
                 'Sentry is not configured'
               )
      end
    end
  end

  describe '.sentry_configured?' do
    context 'when Sentry is initialized' do
      it 'returns true' do
        expect(described_class.send(:sentry_configured?)).to be true
      end
    end

    context 'when Sentry is not initialized' do
      before do
        allow(hub).to receive(:initialized?).and_return(false)
      end

      it 'returns false' do
        expect(described_class.send(:sentry_configured?)).to be false
      end
    end
  end
end
