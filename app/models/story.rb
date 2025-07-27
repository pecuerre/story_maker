class Story < ApplicationRecord
  has_many :location_types, dependent: :destroy
  has_many :locations, dependent: :destroy

  accepts_nested_attributes_for :location_types
end
