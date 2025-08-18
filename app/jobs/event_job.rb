class EventJob < ApplicationJob
  queue_as :events

  def perform(event_name, payload)
    subscribers = Rails.application.config.event_subscribers[event_name] || []

    subscribers.each do |sub|
      begin
        job_class = sub[:job].constantize
        args = Array(sub[:args]).map do |arg|
          arg.is_a?(Symbol) ? payload[arg] : arg
        end
        job_class.perform_later(*args)
      rescue NameError => e # constantized job name raised an exception
        Telescope.capture_error(e)
      end
    end
  end
end
