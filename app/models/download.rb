# Note
# A partial unique index exists on [:fingerprint]
# WHERE current = true to ensure only one "current" version per entity.
# See db/migrate/20250729153120_create_downloads.rb
class Download < ApplicationRecord
  has_one_attached :file, dependent: :purge_later
  belongs_to :source
  has_many :entities, dependent: :destroy
  has_many :extracted_files, dependent: :destroy

  validates :fingerprint, presence: true, uniqueness: { scope: :version }
  validates :name, presence: true
  validates :dataset_code, presence: true
end
