module AssembleeNationaleData
  module Rescuable
    extend ActiveSupport::Concern
    include Telescope::Rescuable

    included do
      class_eval do
        # Define custom error class
        class NetworkError < StandardError; end

        # Set up rescue handler for the custom error
        rescue_from NetworkError, with: :report_network_error
        rescue_from ActiveRecord::RecordInvalid, with: :report_active_record_error
        rescue_from ActiveRecord::RecordNotSaved, with: :report_active_record_error
        rescue_from ActiveRecord::NotNullViolation, with: :report_active_record_error
      end
    end

    private

    def report_network_error(error)
      Telescope.capture_error(error, default_context.merge(error_type: "network"))
      raise error
    end

    # send exception to telescope but do not raise has it will be retry
    # if async without succeeding
    def report_active_record_error(error)
      Telescope.capture_error(error, default_context.merge(error_type: "record"))
    end
  end
end
