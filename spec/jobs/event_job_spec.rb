require 'rails_helper'

RSpec.describe EventJob, type: :job do
  include ActiveJob::TestHelper

  let(:event_name) { 'user_created' }
  let(:payload) { { user_id: 123, email: 'test@example.com', name: 'John Doe' } }
  let(:subscribers) do
    [
      {
        job: 'TestJob',
        args: [ :user_id, :email ]
      },
      {
        job: 'AnotherTestJob',
        args: [ :user_id, 'static_value' ]
      },
      {
        job: 'TestWithNoArgsJob'
      }
    ]
  end

  before do
    allow(Rails.application.config).to receive(:event_subscribers).and_return({
                                                                                event_name => subscribers
                                                                              })
    allow(Telescope).to receive(:capture_error)
  end

  describe '#perform' do
    context 'when subscribers exist for the event' do
      let(:test_job_class) { class_double('TestJob') }
      let(:test_with_no_args_job_class) { class_double('TestWithNoArgsJob') }
      let(:another_test_job_class) { class_double('AnotherTestJob') }

      before do
        stub_const('TestJob', test_job_class)
        stub_const('AnotherTestJob', another_test_job_class)
        stub_const('TestWithNoArgsJob', test_with_no_args_job_class)

        allow(test_job_class).to receive(:perform_later)
        allow(another_test_job_class).to receive(:perform_later)
        allow(test_with_no_args_job_class).to receive(:perform_later)
      end

      it 'enqueues jobs for all subscribers' do
        subject.perform(event_name, payload)

        expect(test_job_class).to have_received(:perform_later).with(123, 'test@example.com')
        expect(another_test_job_class).to have_received(:perform_later).with(123, 'static_value')
        expect(test_with_no_args_job_class).to have_received(:perform_later).with(no_args)
      end

      it 'handles payload keys that do not exist' do
        missing_key_subscribers = [ {
                                     job: 'TestJob',
                                     args: [ :nonexistent_key, :user_id ]
                                   } ]

        allow(Rails.application.config).
          to receive(:event_subscribers).and_return({
                                                      event_name => missing_key_subscribers
                                                    })

        subject.perform(event_name, payload)

        expect(test_job_class).to have_received(:perform_later).with(nil, 123)
      end
    end

    context 'when no subscribers exist for the event' do
      it 'does not enqueue any jobs' do
        allow(Rails.application.config).to receive(:event_subscribers).and_return({})

        expect { subject.perform(event_name, payload) }.not_to raise_error
      end
    end

    context 'when job class cannot be constantized' do
      let(:invalid_subscribers) do
        [ { job: 'NonExistentJob', args: [ :user_id ] } ]
      end

      before do
        allow(Rails.application.config).
          to receive(:event_subscribers).and_return({ event_name => invalid_subscribers })
      end

      it 'captures NameError with Telescope and continues' do
        expect { subject.perform(event_name, payload) }.not_to raise_error

        expect(Telescope).to have_received(:capture_error).with(
          an_instance_of(NameError)
        )
      end

      it 'continues processing other valid subscribers after NameError' do
        mixed_subscribers = [
          { job: 'NonExistentJob', args: [ :user_id ] },
          { job: 'TestJob', args: [ :email ] }
        ]

        allow(Rails.application.config).to receive(:event_subscribers).and_return({
                                                                                    event_name => mixed_subscribers
                                                                                  })

        test_job_class = class_double(TestJob)
        stub_const('TestJob', test_job_class)
        allow(test_job_class).to receive(:perform_later)

        subject.perform(event_name, payload)

        expect(Telescope).to have_received(:capture_error)
        expect(test_job_class).to have_received(:perform_later).with('test@example.com')
      end
    end

    context 'integration test with actual job enqueuing' do
      it 'actually enqueues the jobs' do
        subscribers = [ { job: 'TestJob', args: [ :user_id ] } ]
        allow(Rails.application.config).to receive(:event_subscribers).and_return({
                                                                                    event_name => subscribers
                                                                                  })

        expect {
          subject.perform(event_name, payload)
        }.to have_enqueued_job(TestJob).with(123)
      end
    end
  end

  describe 'job configuration' do
    it 'is queued on the events queue' do
      expect(EventJob.queue_name).to eq('events')
    end
  end
end
