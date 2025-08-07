
require 'rails_helper'

RSpec.describe Telescope::Dispatcher do
  let(:context) { { user_id: 1 } }
  let(:payload) { 'test payload' }
  let(:adapter) { instance_double('Telescope::Adapters::Base') }
  let(:async_dispatcher) { ->(_type, _payload, _context) { } }

  before do
    allow(Telescope.configuration).to receive(:adapters).and_return([ adapter ])
    allow(Telescope.configuration).to receive(:environments).and_return([ 'test' ])
    allow(Telescope.configuration).to receive(:async_dispatcher).and_return(async_dispatcher)
    allow(Rails).to receive(:env).and_return('test')
  end

  describe '.dispatch' do
    context 'with invalid context' do
      let(:context) { 'invalid' }

      it 'raises InvalidContextError' do
        expect {
          described_class.dispatch(:trace, payload, context)
        }.to raise_error(Telescope::InvalidContextError, "Context must be a Hash")
      end
    end

    context 'when disabled' do
      before do
        allow(Telescope.configuration).to receive(:environments).and_return([ 'production' ])
      end

      it 'yields block without dispatching if block given' do
        expect(adapter).not_to receive(:send_trace)
        expect { |b| described_class.dispatch(:trace, payload, context, &b) }.to yield_control
      end

      it 'returns nil if no block given' do
        expect(adapter).not_to receive(:send_trace)
        expect(described_class.dispatch(:trace, payload, context)).to be_nil
      end
    end

    describe 'sampling' do
      let(:sampling_strategy) { ->(_type, _ctx) { true } }
      let(:async_dispatcher) { nil }

      before do
        allow(Telescope.configuration).to receive(:sampling_strategy).and_return(sampling_strategy)
      end

      context 'when sampling strategy returns true' do
        let(:sampling_strategy) { ->(_type, _ctx) { true } }

        it 'dispatches the event' do
          expect(adapter).to receive(:send_trace).with(payload, context)
          described_class.dispatch(:trace, payload, context)
        end
      end

      context 'when sampling strategy returns false' do
        let(:sampling_strategy) { ->(_type, _ctx) { false } }

        it 'skips dispatching the event' do
          expect(adapter).not_to receive(:send_trace)
          described_class.dispatch(:trace, payload, context)
        end

        it 'still yields the block if given' do
          expect(adapter).not_to receive(:send_trace)
          expect { |b| described_class.dispatch(:trace, payload, context, &b) }.to yield_control
        end
      end
    end

    context 'when enabled' do
      context 'with synchronous dispatch' do
        before do
          allow(described_class).to receive(:should_dispatch_async?).and_return(false)
        end

        it 'dispatches to adapter' do
          expect(adapter).to receive(:send_trace).with(payload, context)
          described_class.dispatch(:trace, payload, context)
        end

        it 'yields to block after dispatching' do
          expect(adapter).to receive(:send_trace).with(payload, context)
          expect { |b| described_class.dispatch(:trace, payload, context, &b) }.to yield_control
        end

        context 'when adapter raises error' do
          before do
            allow(adapter).to receive(:send_trace).and_raise(StandardError.new("Adapter error"))
          end

          it 'wraps and raises EventProcessingError' do
            expect {
              described_class.dispatch(:trace, payload, context)
            }.to raise_error(Telescope::EventProcessingError, "Failed to process event: Adapter error")
          end
        end
      end

      context 'with asynchronous dispatch' do
        before do
          allow(described_class).to receive(:should_dispatch_async?).and_return(true)
        end

        it 'calls async_dispatcher' do
          expect(async_dispatcher).to receive(:call).with(:trace, payload, context)
          described_class.dispatch(:trace, payload, context)
        end

        context 'when async_dispatcher is nil' do
          before do
            allow(Telescope.configuration).to receive(:async_dispatcher).and_return(nil)
          end

          it 'falls back to sync dispatch' do
            expect(adapter).to receive(:send_trace).with(payload, context)
            described_class.dispatch(:trace, payload, context)
          end
        end
      end
    end
  end

  describe 'async dispatch decision' do
    context 'with critical error' do
      let(:context) { { severity: :critical } }

      it 'dispatches synchronously' do
        expect(described_class.send(:should_dispatch_async?, :error, context)).to be false
      end
    end

    context 'without async_dispatcher configured' do
      before do
        allow(Telescope.configuration).to receive(:async_dispatcher).and_return(nil)
      end

      it 'dispatches synchronously' do
        expect(described_class.send(:should_dispatch_async?, :trace, context)).to be false
      end
    end

    context 'with regular event and async_dispatcher configured' do
      it 'dispatches asynchronously' do
        expect(described_class.send(:should_dispatch_async?, :trace, context)).to be true
      end
    end
  end
end
