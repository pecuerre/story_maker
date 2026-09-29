class LocationTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "location_tag", taxonomy: "Location"

  soft_deletes :children

  belongs_to :universe
  has_many_tagd :location, scope: :universe_id

  validates :name, presence: true
end
