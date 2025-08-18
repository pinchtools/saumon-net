event_config_path = Rails.root.join("config", "event_subscribers.yml")
EVENT_SUBSCRIBERS = YAML.load_file(event_config_path).with_indifferent_access

Rails.application.config.event_subscribers = EVENT_SUBSCRIBERS
