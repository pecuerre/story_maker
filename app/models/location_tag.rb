class LocationTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "location_tag", taxonomy: "Location"

  belongs_to :universe
  has_many_tagd :location, scope: :universe_id

  validates :name, presence: true
end
