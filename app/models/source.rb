class Source < ApplicationRecord
  has_many :downloads

  validates :name, presence: true
  validates :code, presence: true, uniqueness: true
end
