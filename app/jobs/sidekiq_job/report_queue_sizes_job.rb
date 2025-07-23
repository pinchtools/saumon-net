require "sidekiq/api"

class SidekiqJob::ReportQueueSizesJob < ApplicationJob
  queue_as :monitoring

  def perform
    Sidekiq::Queue.all.each do |queue|
      NewRelic::Agent.record_metric("Custom/Sidekiq/QueueSize/#{queue.name}", queue.size)
    end
  end
end
