module Telescope
  module Adapters
    class Sentry
      class << self
        def send_error(error, context = {})
          raise Telescope::AdapterConfigurationError, "Sentry is not configured" unless sentry_configured?

          ::Sentry.with_scope do |scope|
            set_scope_context(scope, context)
            begin
               ::Sentry.capture_exception(error)
            rescue StandardError => e
              raise ::Telescope::AdapterError, "Sentry error: #{e.message}", cause: e
            end
          end
        end

        def send_log(message, context = {})
          raise Telescope::AdapterConfigurationError, "Sentry is not configured" unless sentry_configured?

          ::Sentry.with_scope do |scope|
            set_scope_context(scope, context)
            begin
              case context[:priority]&.to_sym
              when :high
                ::Sentry.logger.warn(message)
              else
                ::Sentry.logger.info(message)
              end
            rescue StandardError => e
              raise ::Telescope::AdapterError, "Sentry log: #{e.message}", cause: e
            end
          end
        end

        def send_trace(name, payload = {}, context = {})
          raise AdapterConfigurationError, "Sentry is not configured" unless sentry_configured?

          ::Sentry.with_scope do |scope|
            set_scope_context(scope, context)

            transaction = ::Sentry.start_transaction(
              op: "telescope.trace",
              name: name
            )

            ::Sentry.get_current_scope.set_span(transaction)

            begin
              # Add payload data as span data
              payload.each do |key, value|
                transaction.set_data(key.to_s, value)
              end

              # If there's a duration in the payload, set it
              if payload[:duration]
                transaction.set_timestamp(Time.now.to_f)
                transaction.set_duration(payload[:duration])
              end

              yield transaction if block_given?
            rescue => e
              raise e
            ensure
              transaction.finish
            end
          end
        rescue AdapterConfigurationError => e
          raise e
        rescue => e
          raise Telescope::AdapterError, "Sentry trace error: #{e.message}", cause: e
        end

        private

        def sentry_configured?
          defined?(::Sentry) && ::Sentry.initialized?
        end

        def set_scope_context(scope, context)
          raise Telescope::InvalidContextError, "Context must be a Hash" unless context.is_a?(Hash)

          scope.set_extras(filter_sensitive_data(context))
          scope.set_user(filter_sensitive_data(context[:user])) if context[:user].is_a?(Hash)
          scope.set_tags(filter_sensitive_data(context[:tags])) if context[:tags].is_a?(Hash)
          scope.set_context("request", filter_sensitive_data(context[:request])) if context[:request].is_a?(Hash)

          # Non-filtered attributes
          scope.set_fingerprint(context[:fingerprint]) if context[:fingerprint].is_a?(Array)
          scope.set_level(context[:level]) if context[:level]
          scope.set_transaction_name(context[:transaction]) if context[:transaction]
        rescue StandardError => e
          raise Telescope::AdapterError, "Failed to set Sentry scope: #{e.message}", cause: e
        end

        def filter_sensitive_data(data)
          return data unless data.is_a?(Hash)

          data.each_with_object({}) do |(key, value), result|
            filtered_value = if should_filter?(key) || (value.is_a?(String) && should_filter?(value))
                               "[FILTERED]"
            elsif value.is_a?(Hash)
                               filter_sensitive_data(value)
            elsif value.is_a?(Array)
                               value.map { |v| v.is_a?(Hash) ? filter_sensitive_data(v) : v }
            else
                               value
            end

            result[key] = filtered_value
          end
        end

        def should_filter?(key_or_value)
          Telescope.configuration.filtered_parameters.any? do |pattern|
            case pattern
            when Regexp
              key_or_value.to_s.match?(pattern)
            else
              key_or_value.to_s.include?(pattern.to_s)
            end
          end
        end
      end
    end
  end
end
