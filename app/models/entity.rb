class Entity < ApplicationRecord
  belongs_to :download

  validates :uid, uniqueness: true, presence: true
  validates :type, presence: true
end
