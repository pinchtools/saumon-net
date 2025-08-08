RSpec.describe Telescope::RescueWrapper do
  context 'when rescue_with_handler is defined and return true' do
    let(:test_class) do
      Class.new do
        prepend Telescope::RescueWrapper

        def normal_method; raise StandardError, "standard error"; end
        def another_method; "success"; end

        private

        def rescue_with_handler(_error)
          @error_was_handled = true
          true # indicate that we handled the error
        end

        def error_was_handled?; @error_was_handled; end
      end
    end

    let(:instance) { test_class.new }

    it 'handles errors through rescue_with_handler' do
      expect { instance.normal_method }.not_to raise_error # shouldn't raise because handler returns true
      expect(instance.error_was_handled?).to be true
    end
  end

  context 'when rescue_with_handler returns false' do
    let(:test_class) do
      Class.new do
        prepend Telescope::RescueWrapper

        def normal_method; raise StandardError, "standard error"; end

        private

        def rescue_with_handler(error); false; end # indicate that we didn't handle the error
      end
    end

    let(:instance) { test_class.new }

    it 'raises the original error' do
      expect { instance.normal_method }.to raise_error(StandardError, "standard error")
    end
  end

  context 'when rescue_with_handler is not defined' do
    let(:test_class) do
      Class.new do
        prepend Telescope::RescueWrapper

        def normal_method; raise StandardError, "standard error"; end
        def another_method; "success"; end

        def method_with_args(arg1, arg2:)
          raise ArgumentError, "arg error" if arg1.nil?
          [ arg1, arg2 ]
        end

        # Methods starting with report_ should not be wrapped
        def report_something; raise "this should not be rescued"; end

        private

        def private_method; raise RuntimeError, "private error"; end
      end
    end

    let(:instance) { test_class.new }

    describe 'method wrapping' do
      it 'wraps existing public methods' do
        expect { instance.normal_method }.to raise_error(StandardError)
      end

      it 'wraps private methods' do
        expect { instance.private_method }.to raise_error(StandardError)
      end

      it 'does not wrap methods starting with report_' do
        expect { instance.report_something }.to raise_error(RuntimeError)
      end

      it 'preserves method arguments' do
        result = instance.method_with_args("test", arg2: "value")
        expect(result).to eq([ "test", "value" ])
      end

      it 'handles methods that do not raise errors' do
        expect(instance.another_method).to eq("success")
      end
    end

    describe 'dynamic method addition' do
      it 'wraps methods added after class definition' do
        test_class.class_eval do
          def dynamically_added_method
            raise StandardError, "dynamic error"
          end
        end

        expect { instance.dynamically_added_method }.to raise_error(StandardError)
      end

      it 'does not wrap report_ methods added dynamically' do
        test_class.class_eval do
          def report_dynamic
            raise "report error"
          end
        end

        expect { instance.report_dynamic }.to raise_error(RuntimeError)
      end
    end

    describe 'method wrapping idempotency' do
      it 'does not wrap methods multiple times' do
        test_class.prepend(Telescope::RescueWrapper)

        # Count how many times rescue_with_handler is called
        call_count = 0
        instance.define_singleton_method(:rescue_with_handler) do |error|
          call_count += 1
          true
        end

        instance.normal_method
        expect(call_count).to eq(1)
      end
    end
  end
end
