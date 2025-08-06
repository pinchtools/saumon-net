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

  rescue Telescope::Error => e
    Rails.logger.error("[Telescope] #{e.message}")
    raise
  rescue StandardError => e
    Rails.logger.error("Failed to process telescope event: #{e.message}")
    raise
  end

  retry_on Telescope::Error, wait: :exponentially_longer, attempts: 5
  retry_on StandardError, wait: :exponentially_longer, attempts: 3
end
