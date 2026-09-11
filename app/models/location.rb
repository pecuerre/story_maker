class Location < ApplicationRecord
  include Hierarchical
  include HasManyTypes

  belongs_to :story
  has_many_types :location_type

  validates :name, presence: true
end
