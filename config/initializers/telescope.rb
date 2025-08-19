require "telescope"

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
    when :trace, :log
      if context[:priority] == :high
        TelescopeJob.perform_now(type, payload, context)
      else
        TelescopeJob.perform_later(type, payload, context)
      end
    end
  }
  config.sampling_rate = case Rails.env.to_s
  when "production"
                           0.0
  when "staging"
                           0.0
  else
                           0.0
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
