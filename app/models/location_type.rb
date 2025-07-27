class LocationType < ApplicationRecord
  belongs_to :story
  has_many :locations, dependent: :destroy
end
