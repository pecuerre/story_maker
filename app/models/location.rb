class Location < ApplicationRecord
  belongs_to :story
  belongs_to :location_type
  include Hierarchical

  validates :name, presence: true
end
