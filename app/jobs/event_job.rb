class EventJob < ApplicationJob
  queue_as :events

  def perform(event_name, payload)
    subscribers = Rails.application.config.event_subscribers[event_name] || []

    subscribers.each do |sub|
      begin
        job_class = sub[:job].constantize
        args = process_args(sub[:args], payload)
        job_class.perform_later(*args)
      rescue NameError => e # constantized job name raised an exception
        Telescope.capture_error(e)
      end
    end
  end

  private

  def process_args(args_config, payload)
    return [] if args_config.nil?

    Array(args_config).map do |arg|
      case arg
      when Symbol
        payload[arg]
      when Hash
        process_hash_context(arg, payload)
      else
        arg
      end
    end
  end

  def process_hash_context(hash_arg, payload)
    processed_hash = {}

    hash_arg.each do |key, value|
      processed_hash[key] = value.is_a?(Symbol) ? payload[value] : value
    end

    processed_hash
  end
end
