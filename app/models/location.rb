class Location < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tags :location_tag

  validates :name, presence: true
end
