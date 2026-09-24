class LocationTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tagd :location, scope: :universe_id

  validates :name, presence: true
end
