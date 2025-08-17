class DownloadVersioningService
  include Telescope::Rescuable

  attr_reader :name, :fingerprint, :dataset_code, :source

  def initialize(name:, fingerprint:, dataset_code:, source:)
    @name = name
    @fingerprint = fingerprint
    @dataset_code = dataset_code
    @source = source
  end

  def call
    return unless valid?

    ActiveRecord::Base.transaction do
      current_download&.update!(current: false)
      source.downloads.create!(
        name: name,
        fingerprint: fingerprint,
        dataset_code: dataset_code,
        version: next_version,
        current: true
      )
    end
  end

  def valid?
    source.present?
  end

  private

  def current_download
    @current_download ||= source.downloads.find_by(fingerprint: fingerprint, current: true)
  end

  def next_version
    @next_version ||= source.downloads.where(fingerprint: fingerprint).maximum(:version).to_i + 1
  end
end
