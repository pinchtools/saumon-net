class Telescope::LogJob < ApplicationJob
  queue_as :default

  def perform(message, context)
    Telescope.log(message, context)
  end
end
