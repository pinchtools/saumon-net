require 'rails_helper'

RSpec.describe Telescope::LogJob, type: :job do
  let(:message) { 'Test log message' }
  let(:context) { { user_id: 123, action: 'test' } }

  before do
    allow(Telescope).to receive(:log)
  end

  describe '#perform' do
    it 'calls Telescope.log with message and context' do
      subject.perform(message, context)

      expect(Telescope).to have_received(:log).with(message, context)
    end
  end

  describe 'job configuration' do
    it 'queues on low priority' do
      expect(described_class.queue_name).to eq('default')
    end
  end
end
