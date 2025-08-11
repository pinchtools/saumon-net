module Telescope
  module Rescuable
    extend ActiveSupport::Concern
    include ActiveSupport::Rescuable
    prepend Telescope::RescueWrapper

    included do
      rescue_from StandardError, with: :report_general_error
    end

    private

    def report_general_error(error)
      Telescope.capture_error(error, default_context)
      raise error
    end

    def default_context
      {
        class: self.class.name,
        timestamp: Time.current
      }
    end
  end
end
