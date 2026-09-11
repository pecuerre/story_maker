class LocationType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes

  belongs_to :story
  has_many_typed :location

  validates :name, presence: true
end
