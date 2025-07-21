Sidekiq::Cron.configure do |config|
  config.cron_poll_interval = 30 # Default is 30
  config.cron_schedule_file = "config/job_scheduler.yml" # Default is 'config/schedule.yml'
  config.cron_history_size = 20 # Default is 10
  config.default_namespace = "default" # Default is 'default'
  config.available_namespaces = %w[default downloader maintenance] # Default is `[config.default_namespace]`
  config.natural_cron_parsing_mode = :strict # Default is :single
  config.reschedule_grace_period = 60 # Default is 60
end
