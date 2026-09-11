class LocationType < ApplicationRecord
  include Hierarchical
  include HasColor

  belongs_to :story
  has_many :locations, dependent: :destroy

  validates :name, presence: true
end
