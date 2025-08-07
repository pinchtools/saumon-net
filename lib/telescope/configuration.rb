module Telescope
  class Configuration
    attr_accessor :environments, :sampling_rate, :filtered_parameters
    attr_writer :adapters, :async_dispatcher, :sampling_strategy

    def initialize
      @environments = %w[development test staging production]
      @filtered_parameters = Rails.application.config.filter_parameters
    end

    def adapters
      @adapters ||= [ Adapters::Sentry, Adapters::Logger ]
    end

    def async_dispatcher
      @async_dispatcher ||= nil
    end

    def sampling_strategy
      @sampling_strategy ||= ->(type, context) {
        case type
        when :error
          # Always sample errors
          true
        when :trace
          if context[:priority] == :high
            # Always sample high priority traces
            true
          else
            # Use standard sampling rate for regular traces
            Random.rand <= sampling_rate
          end
        else
          Random.rand <= sampling_rate
        end
      }
    end
  end
end
