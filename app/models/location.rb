class Location < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts
  include Searchable
  searchable kind: "location", title: :name, body: :description, route: "location"

  invalidates_menu_counts_for :universe

  belongs_to :universe
  has_many_tags :location_tag, scope: :universe_id
  # The Scene presence side. Deleting a Location removes its presence links; it
  # never removes a Scene, and the Location itself is shared by every Story.
  has_many :scene_locations, dependent: :delete_all

  validates :name, presence: true
end
