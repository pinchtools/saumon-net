module Telescope
  module Adapters
    class Logger
      class << self
        def send_error(error, context = {})
          Rails.logger.error("[Telescope] #{error.class}: #{error.message}")
          Rails.logger.error(context.to_json) if context.any?
          Rails.logger.error(error.backtrace.join("\n")) if error.backtrace
        end

        def send_log(message, context = {})
          log_method = context[:priority]&.to_sym == :high ? :warn : :info
          Rails.logger.send(log_method, "[Telescope] #{message}")
          Rails.logger.send(log_method, context.to_json) if context.any?
        end

        def send_trace(name, context = {}, &block)
          Rails.logger.info("[Telescope] #{name} started")
          Rails.logger.info(context.to_json) if context.any?

          if block_given?
            start_time = Time.current
            begin
              yield
            ensure
              duration = Time.current - start_time
              Rails.logger.info("[Telescope] #{name} completed in #{duration}s")
            end
          end
        end
      end
    end
  end
end
