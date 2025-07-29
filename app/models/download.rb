# Note
# A partial unique index exists on [:fingerprint]
# WHERE current = true to ensure only one "current" version per entity.
# See db/migrate/20250729153120_create_downloads.rb
class Download < ApplicationRecord
  belongs_to :source

  validates :fingerprint, presence: true, uniqueness: { scope: :version }

  validates :name, presence: true
end
