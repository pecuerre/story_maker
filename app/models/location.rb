class Location < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  searchable kind: "location", title: :name, body: :description, route: "location"
  invalidates_menu_counts_for :universe
  soft_deletes :children, :scene_locations, :routes_from, :routes_to

  belongs_to :universe
  has_many_tags :location_tag, scope: :universe_id
  # The Scene presence side. Deleting a Location removes its presence links; it
  # never removes a Scene, and the Location itself is shared by every Story.
  # `:destroy` rather than `:delete_all`: a presence link carries a discussion,
  # and `delete_all` skips the callbacks that would take it along. See Character.
  has_many :scene_locations, dependent: :destroy
  has_many :routes_from, class_name: "Route", foreign_key: :from_location_id, dependent: :destroy
  has_many :routes_to, class_name: "Route", foreign_key: :to_location_id, dependent: :destroy

  validates :name, presence: true
end
