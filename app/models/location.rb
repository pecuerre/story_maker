class Location < ApplicationRecord
  include Hierarchical

  belongs_to :story
  belongs_to :location_type

  validates :name, presence: true
end
