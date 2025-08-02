class TelescopeJob < ApplicationJob
  queue_as do
    case arguments.first
    when :error
      :default
    else
      :low
    end
  end

  def perform(type, payload, context)
    Telescope::Dispatcher.send(:dispatch_sync, type, payload, context)
  end

  retry_on StandardError, wait: :exponentially_longer, attempts: 3

  rescue_from(StandardError) do |exception|
    Rails.logger.error("Failed to process telescope event: #{exception.message}")

    Sentry.capture_exception(exception) if defined?(Sentry)
  end
end
