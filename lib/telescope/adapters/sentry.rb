module Telescope
  module Adapters
    class Sentry
      def send_error(error, context = {})
        raise AdapterConfigurationError, "Sentry is not configured" unless sentry_configured?

        ::Sentry.with_scope do |scope|
          set_scope_context(scope, context)
          ::Sentry.capture_exception(error)
        end
      end

      def send_trace(name, payload = {}, context = {})
        raise AdapterConfigurationError, "Sentry is not configured" unless sentry_configured?

        ::Sentry.with_scope do |scope|
          set_scope_context(scope, context)

          ::Sentry.with_trace(op: "telescope.trace", name: name) do |span|
            # Add payload data as span data
            payload.each do |key, value|
              span.set_data(key.to_s, value)
            end

            # If there's a duration in the payload, set it
            if payload[:duration]
              span.set_timestamp(Time.now.to_f)
              span.set_duration(payload[:duration])
            end

            yield span if block_given?
          end
        end
      rescue ::Sentry::Error => e
        raise AdapterError, "Sentry trace error: #{e.message}", cause: e
      end

      private

      def sentry_configured?
        defined?(::Sentry) && ::Sentry.initialized?
      end

      def set_scope_context(scope, context)
        raise InvalidContextError, "Context must be a Hash" unless context.is_a?(Hash)

        scope.set_extras(filter_sensitive_data(context))
        scope.set_user(filter_sensitive_data(context[:user])) if context[:user].is_a?(Hash)
        scope.set_tags(filter_sensitive_data(context[:tags])) if context[:tags].is_a?(Hash)
        scope.set_context("request", filter_sensitive_data(context[:request])) if context[:request].is_a?(Hash)

        # Non-filtered attributes
        scope.set_fingerprint(context[:fingerprint]) if context[:fingerprint].is_a?(Array)
        scope.set_level(context[:level]) if context[:level]
        scope.set_transaction_name(context[:transaction]) if context[:transaction]
      rescue StandardError => e
        raise AdapterError, "Failed to set Sentry scope: #{e.message}", cause: e
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
