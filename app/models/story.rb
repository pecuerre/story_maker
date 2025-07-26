class Story < ApplicationRecord
  has_many :location_types

  accepts_nested_attributes_for :location_types
end
