require 'rails_helper'

RSpec.describe AssembleeNationaleData::Rescuable do
  let(:test_class) do
    Class.new do
      include AssembleeNationaleData::Rescuable

      attr_reader :error_context_received

      def trigger_network_error
        raise Telescope::NetworkError, "network failure"
      end

      def trigger_record_invalid
        raise ActiveRecord::RecordInvalid.new
      end


      def trigger_record_not_saved
        raise ActiveRecord::RecordNotSaved.new("not saved", self)
      end

      def trigger_not_null_violation
        raise ActiveRecord::NotNullViolation.new("null violation")
      end

      def trigger_standard_error
        raise StandardError, "standard error"
      end
    end
  end

  let(:instance) { test_class.new }
  let(:current_time) { Time.current }

  before do
    allow(Time).to receive(:current).and_return(current_time)
    allow(Telescope).to receive(:capture_error)
  end

  describe 'NetworkError handling' do
    it 'captures and re-raises network errors' do
      expect(Telescope).to receive(:capture_error).with(
        kind_of(Telescope::NetworkError),
        hash_including(
          error_type: "network",
          class: test_class.name,
          timestamp: current_time
        )
      )

      expect { instance.trigger_network_error }.to raise_error(Telescope::NetworkError)
    end
  end

  describe 'ActiveRecord error handling' do
    shared_examples "active record error handling" do |error_method|
      it 'captures but does not re-raise the error' do
        expect(Telescope).to receive(:capture_error).with(
          kind_of(error_class),
          hash_including(
            error_type: "record",
            class: test_class.name,
            timestamp: current_time
          )
        )

        expect { instance.public_send(error_method) }.not_to raise_error
      end
    end

    context 'with RecordInvalid' do
      let(:error_class) { ActiveRecord::RecordInvalid }
      it_behaves_like "active record error handling", :trigger_record_invalid
    end

    context 'with RecordNotSaved' do
      let(:error_class) { ActiveRecord::RecordNotSaved }
      it_behaves_like "active record error handling", :trigger_record_not_saved
    end

    context 'with NotNullViolation' do
      let(:error_class) { ActiveRecord::NotNullViolation }
      it_behaves_like "active record error handling", :trigger_not_null_violation
    end
  end

  describe 'inheritance of Telescope::Rescuable' do
    it 'handles standard errors through the parent module' do
      expect(Telescope).to receive(:capture_error).with(
        kind_of(StandardError),
        hash_including(
          class: test_class.name,
          timestamp: current_time
        )
      )

      expect { instance.trigger_standard_error }.to raise_error(StandardError)
    end
  end
end
