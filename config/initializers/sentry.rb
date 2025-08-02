# frozen_string_literal: true

Sentry.init do |config|
  config.breadcrumbs_logger = [ :active_support_logger, :http_logger ]
  config.dsn = Rails.application.credentials.sentry.dsn!
  config.enabled_environments = %w[development staging production]

  # Add data like request headers and IP for users,
  # see https://docs.sentry.io/platforms/ruby/data-management/data-collected/ for more info
  config.send_default_pii = false

  # Set traces_sample_rate to 1.0 to capture 100%
  # of transactions for tracing.
  # We recommend adjusting this value in production.
  config.traces_sample_rate = 1.0
  # or
  # config.traces_sampler = lambda do |context|
  #   # Sample based on transaction type
  #   case context[:transaction_name]
  #   when /health_check/
  #     0.0  # Don't sample health checks
  #   when /api\//
  #     0.5  # Sample 50% of API calls
  #   else
  #     0.1  # Sample 10% of everything else
  #   end
  # end

end
