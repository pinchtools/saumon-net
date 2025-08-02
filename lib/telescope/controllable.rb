module Telescope
  module Controllable
    extend ActiveSupport::Concern

    included do
      rescue_from StandardError, with: :telescope_capture_error
      around_action :telescope_trace_request
    end

    private

    def telescope_capture_error(error)
      Telescope.capture_error(error, telescope_error_context)
    rescue Telescope::Error => e
      Rails.logger.error("[Telescope] Failed to capture error: #{e.message}")
      raise error # Still raise the original error if telescope fails
    end

    def telescope_trace_request
      Telescope.trace("#{controller_name}##{action_name}", telescope_request_context) do
        yield
      end
    end

    def telescope_error_context
      {
        controller: controller_name,
        action: action_name,
        params: filtered_params,
        url: request.url,
        method: request.method,
        remote_ip: request.remote_ip,
        user_agent: request.user_agent
      }
    end

    def telescope_request_context
      {
        controller: controller_name,
        action: action_name,
        format: request.format.to_s,
        method: request.method
      }
    end

    def filtered_params
      request.filtered_parameters
    end
  end
end
