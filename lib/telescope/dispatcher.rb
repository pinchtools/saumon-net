module Telescope
  module Dispatcher
    class << self
      def dispatch(type, payload, context = {}, &block)
        raise InvalidContextError, "Context must be a Hash" unless context.is_a?(Hash)

        return yield if block_given? && !enabled?
        return yield if block_givent? && !should_sample?

        if should_dispatch_async?(type, context)
          dispatch_async(type, payload, context)
        else
          dispatch_sync(type, payload, context, &block)
        end

        yield if block_given?
      end

      private

      def dispatch_sync(type, payload, context, &block)
        Telescope.configuration.adapters.each do |adapter|
          begin
            if block_given?
              adapter.public_send("send_#{type}", payload, context, &block)
            else
              adapter.public_send("send_#{type}", payload, context)
            end
          rescue StandardError => e
            raise EventProcessingError, "Failed to process event: #{e.message}", cause: e
          end
        end
      end

      def dispatch_async(type, payload, context)
        async_dispatcher = Telescope.configuration.async_dispatcher
        return dispatch_sync(type, payload, context) unless async_dispatcher


        async_dispatcher.call(type, payload, context)
      end

      def should_dispatch_async?(type, context)
        return false if type == :error && context[:severity] == :critical
        return false if Telescope.configuration.force_sync
        return false if Telescope.configuration.async_dispatcher.nil?

        true
      end

      def should_sample?(type, context)
        strategy = Telescope.configuration.sampling_strategy
        strategy.call(type, context)
      end

      def enabled?
        Telescope.configuration.environments.include?(Rails.env)
      end
    end
  end
end
