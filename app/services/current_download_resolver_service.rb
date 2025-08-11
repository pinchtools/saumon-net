class CurrentDownloadResolverService
  include Telescope::Rescuable

  attr_reader :fingerprint, :source, :current

  def initialize(fingerprint:, source:)
    @fingerprint = fingerprint
    @source = source
  end

  def call
    return unless valid?

    source.downloads.find_or_initialize_by(fingerprint: fingerprint, current: true).tap do |download|
      download.version = max_version + 1 if download.new_record?
    end
  end

  def valid?
    (fingerprint.present? && source.present?)
  end

  private

  def max_version
    @next_version ||= source.downloads.where(fingerprint: fingerprint).maximum(:version).to_i
  end
end
