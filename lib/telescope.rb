module Telescope
  autoload :Dispatcher, "telescope/dispatcher"
  autoload :Configuration, "telescope/configuration"
  autoload :Controllable, "telescope/controllable"
  autoload :Rescuable, "telescope/rescuable"
  autoload :RescueWrapper, "telescope/rescue_wrapper"
  autoload :Adapters, "telescope/adapters"

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
  class NetworkError < StandardError; end

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

    def log(message, context = {})
      Dispatcher.dispatch(:log, message, enrich_context(context))
    end

    private

    def enrich_context(context)
      context.merge(
        environment: Rails.env.to_s,
        timestamp: Time.current.to_i,
        process_id: Process.pid
      )
    end
  end
end
