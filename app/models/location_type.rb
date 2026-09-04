class LocationType < ApplicationRecord
  include Hierarchical

  belongs_to :story
  has_many :locations, dependent: :destroy

  validates :name, presence: true
end
