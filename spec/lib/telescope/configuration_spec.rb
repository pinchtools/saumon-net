require 'rails_helper'

RSpec.describe Telescope::Configuration do
  subject(:configuration) { described_class.new }

  describe '#initialize' do
    it 'sets default environments' do
      expect(configuration.environments).to eq(%w[development test staging production])
    end

    it 'sets filtered parameters from Rails config' do
      expect(configuration.filtered_parameters).to eq(Rails.application.config.filter_parameters)
    end
  end

  describe '#adapters' do
    context 'when adapters are not set' do
      it 'returns default adapters' do
        expect(configuration.adapters).to eq([ Telescope::Adapters::Sentry, Telescope::Adapters::Logger ])
      end
    end

    context 'when adapters are explicitly set' do
      let(:custom_adapters) { [ double('CustomAdapter') ] }
      before { configuration.adapters = custom_adapters }

      it 'returns the configured adapters' do
        expect(configuration.adapters).to eq(custom_adapters)
      end
    end
  end

  describe '#async_dispatcher' do
    context 'when not set' do
      it { expect(configuration.async_dispatcher).to be_nil }
    end

    context 'when explicitly set' do
      let(:custom_dispatcher) { double('AsyncDispatcher') }
      before { configuration.async_dispatcher = custom_dispatcher }

      it 'returns the configured dispatcher' do
        expect(configuration.async_dispatcher).to eq(custom_dispatcher)
      end
    end
  end

  describe '#sampling_strategy' do
    context 'when not set' do
      it 'returns a default lambda' do
        expect(configuration.sampling_strategy).to be_a(Proc)
      end

      describe 'default strategy behavior' do
        let(:strategy) { configuration.sampling_strategy }

        shared_examples 'sampling with probability' do |event_type|
          before do
            configuration.sampling_rate = 0.5
            allow(Random).to receive(:rand).and_return(random_value)
          end

          context 'when random value is below sampling rate' do
            let(:random_value) { 0.4 }

            it 'samples the event' do
              expect(strategy.call(event_type, context)).to be true
            end
          end

          context 'when random value is above sampling rate' do
            let(:random_value) { 0.6 }

            it 'does not sample the event' do
              expect(strategy.call(event_type, context)).to be false
            end
          end
        end

        context 'with error type' do
          let(:context) { {} }

          context 'with critical severity' do
            let(:context) { { severity: :critical } }

            it 'never samples high priority traces' do
              expect(strategy.call(:error, context)).to be false
            end
          end

          context 'with regular severity' do
            it_behaves_like 'sampling with probability', :error
          end
        end

        context 'with trace type' do
          let(:context) { {} }

          context 'with high priority' do
            let(:context) { { priority: :high } }

            it 'never samples high priority traces' do
              expect(strategy.call(:trace, context)).to be false
            end
          end

          context 'with regular priority' do
            it_behaves_like 'sampling with probability', :trace
          end
        end

        context 'with other types' do
          let(:context) { {} }
          it_behaves_like 'sampling with probability', :other
        end
      end
    end

    context 'when explicitly set' do
      let(:custom_strategy) { ->(_type, _context) { true } }

      before do
        configuration.sampling_strategy = custom_strategy
      end

      it 'returns the configured strategy' do
        expect(configuration.sampling_strategy).to eq(custom_strategy)
      end
    end
  end
end
