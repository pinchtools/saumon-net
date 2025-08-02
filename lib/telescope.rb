module Telescope
  # Base error class for all Telescope errors
  class Error < StandardError; end

  # Configuration related errors
  class ConfigurationError < Error; end
  class InvalidConfigurationError < ConfigurationError; end

  # Adapter related errors
  class AdapterError < Error; end
  class AdapterConfigurationError < AdapterError; end

  # Event handling errors
  class EventError < Error; end
  class EventProcessingError < EventError; end

  # Context related errors
  class ContextError < Error; end
  class InvalidContextError < ContextError; end


  class << self
    def configure
      yield(configuration)
    end

    def configuration
      @configuration ||= Configuration.new
    end

    def capture_error(error, context = {})
      Dispatcher.dispatch(:error, error, enrich_context(context))
    end

    def trace(name, context = {}, &block)
      if block_given?
        Dispatcher.dispatch(:trace, name, enrich_context(context), &block)
      else
        Dispatcher.dispatch(:trace, name, enrich_context(context))
      end
    end

    private

    def enrich_context(context)
      context.merge(
        environment: Rails.env,
        timestamp: Time.current,
        process_id: Process.pid
      )
    end
  end
end
