class Entity < ApplicationRecord
  self.inheritance_column = nil

  belongs_to :download
  belongs_to :extracted_file, optional: true

  validates :uid, uniqueness: true, presence: true
  validates :type, presence: true
end
