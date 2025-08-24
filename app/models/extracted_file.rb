class ExtractedFile < ApplicationRecord
  has_one_attached :file, dependent: :purge_later
  belongs_to :download
  has_many :entities, dependent: :destroy

  validates :path, presence: true
  validates :download, presence: true
  validates :path, uniqueness: { scope: :download }
end
