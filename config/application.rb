require_relative "boot"

require "rails"
# Pick the frameworks you want:
require "active_model/railtie"
require "active_job/railtie"
require "active_record/railtie"
require "active_storage/engine"
require "action_controller/railtie"
require "action_mailer/railtie"
require "action_mailbox/engine"
require "action_text/engine"
require "action_view/railtie"
require "action_cable/engine"
# require "rails/test_unit/railtie"

# Require the gems listed in Gemfile, including any gems
# you've limited to :test, :development, or :production.
Bundler.require(*Rails.groups)

module SaumonNet
  class Application < Rails::Application
    # Initialize configuration defaults for originally generated Rails version.
    config.load_defaults 8.0

    # Please, add to the `ignore` list any other `lib` subdirectories that do
    # not contain `.rb` files, or that should not be reloaded or eager loaded.
    # Common ones are `templates`, `generators`, or `middleware`, for example.
    config.autoload_lib(ignore: %w[assets tasks])

    # Configuration for the application, engines, and railties goes here.
    #
    # These settings can be overridden in specific environments using the files
    # in config/environments, which are processed later.
    #
    # config.time_zone = "Central Time (US & Canada)"
    # config.eager_load_paths << Rails.root.join("extras")

    # Only loads a smaller set of middleware suitable for API only apps.
    # Middleware like session, flash, cookies can be added back manually.
    # Skip views, helpers and assets when generating a new resource.
    config.api_only = true

    config.after_initialize do
      Telescope.configure do |config|
        config.environments = %w[development staging production]
        config.adapters = [
          Telescope::Adapters::Sentry,
          Telescope::Adapters::Logger
        ]
        config.async_dispatcher = ->(type, payload, context) {
          case type
          when :error
            TelescopeJob.perform_now(type, payload, context)
          when :trace
            if context[:priority] == :high
              TelescopeJob.perform_now(type, payload, context)
            else
              TelescopeJob.perform_later(type, payload, context)
            end
          end
        }
        config.sampling_rate = case Rails.env
        when "production"
                                 1.0
        when "staging"
                                 1.0
        else
                                 1.0
        end
        config.filtered_parameters += Set.new([
                                                Rails.application.config.filter_parameters,
                                                /password/i,
                                                /passwd/i,
                                                /secret/i,
                                                /token/i,
                                                /api[_-]?key/i,
                                                /access[_-]?key/i,
                                                /auth/i,
                                                /credential/i,
                                                /private[_-]?key/i,
                                                /ssn/i,
                                                /social[_-]?security/i,
                                                /credit[_-]?card/i,
                                                /card[_-]?number/i,
                                                /cvv/i
                                              ].flatten).to_a
      end
    end
  end
end
