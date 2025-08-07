require 'rails_helper'

class DummyControllableController < ActionController::Base
  include Telescope::Controllable

  def index
    render plain: 'OK'
  end

  def trigger_standard_error
    raise StandardError, 'Test error'
  end
end

RSpec.describe DummyControllableController, type: :controller do
  describe 'error handling' do
    context 'when an error occurs' do
      before { routes.draw { get 'trigger_standard_error' => 'dummy_controllable#trigger_standard_error' } }

      let(:expected_context) do
        hash_including({
          controller: 'dummy_controllable',
          action: 'trigger_standard_error',
          params: kind_of(Hash),
          url: kind_of(String),
          method: 'GET',
          remote_ip: kind_of(String),
          user_agent: kind_of(String),
          format: 'text/html'
        })
      end

      it 'captures the error with Telescope' do
        expect(Telescope).to receive(:capture_error).with(kind_of(StandardError), expected_context)

        get :trigger_standard_error

        expect { response }.not_to raise_error
      end
    end

    context 'when Telescope fails' do
      before do
        routes.draw { get 'trigger_standard_error' => 'dummy_controllable#trigger_standard_error' }
        allow(Telescope).to receive(:capture_error)
                              .and_raise(Telescope::Error.new('Capture failed'))
        allow(Rails.logger).to receive(:error)
      end

      it 'logs the failure and re-raises the original error' do
        expect(Rails.logger).to receive(:error)
                                  .with('[Telescope] Failed to capture error: Capture failed')

        expect { get :trigger_standard_error }.to raise_error(StandardError, 'Test error')
      end
    end
  end

  describe 'request tracing' do
    before do
      routes.draw { get 'index' => 'dummy_controllable#index' }
    end

    let(:expected_context) do
      {
        controller: 'dummy_controllable',
        action: 'index',
        format: 'text/html',
        method: 'GET'
      }
    end

    it 'traces the request' do
      expect(Telescope).to receive(:trace)
                             .with('dummy_controllable#index', expected_context)
                             .and_call_original

      get :index
      expect(response).to be_successful
    end
  end
end
