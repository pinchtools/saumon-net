# spec/lib/telescope/rescuable_spec.rb
require 'rails_helper'

class CustomError < StandardError; end

RSpec.describe Telescope::Rescuable do
  let(:test_class) do
    custom_error = CustomError # capture the reference to use inside the class
    Class.new do
      include Telescope::Rescuable

      # Reference the error class through a constant
      const_set(:CustomError, custom_error)

      def trigger_standard_error
        raise StandardError, "standard error"
      end

      def trigger_custom_error
        raise CustomError, "custom error"
      end

      def report_custom_error(error)
        @custom_handled = true
        raise error
      end
    end
  end

  let(:instance) { test_class.new }

  # Mock Telescope.capture_error for our tests
  before do
    allow(Telescope).to receive(:capture_error)
    allow(Time).to receive(:current).and_return(Time.new(2025, 1, 1, 12, 0, 0))
  end

  describe 'error handling' do
    context 'with default StandardError handler' do
      it 'captures and re-raises StandardError' do
        expect(Telescope).to receive(:capture_error).with(
          instance_of(StandardError),
          {
            class: instance.class.name,
            timestamp: Time.current
          }
        )

        expect { instance.trigger_standard_error }.to raise_error(StandardError, "standard error")
      end
    end

    context 'with custom error handlers' do
      before do
        test_class.rescue_from(test_class::CustomError, with: :report_custom_error)
      end

      it 'routes custom errors to their specific handlers' do
        expect(Telescope).not_to receive(:capture_error)
        expect { instance.trigger_custom_error }.to raise_error(test_class::CustomError)
        expect(instance.instance_variable_get(:@custom_handled)).to be true
      end
    end
  end

  describe 'error propagation' do
    context 'when handling nested errors' do
      let(:test_class_with_nested) do
        Class.new do
          include Telescope::Rescuable

          def nested_error
            begin
              raise StandardError, "inner error"
            rescue
              raise StandardError, "outer error"
            end
          end
        end
      end

      let(:nested_instance) { test_class_with_nested.new }

      it 'captures the most recent error' do
        expect(Telescope).to receive(:capture_error).with(
          instance_of(StandardError),
          hash_including(class: nested_instance.class.name)
        )

        expect { nested_instance.nested_error }.to raise_error("outer error")
      end
    end
  end
end
