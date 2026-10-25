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

  searchable kind: "location", title: :name, body: :search_description, route: "location"
  invalidates_menu_counts_for :universe
  soft_deletes :children, :scene_locations, :routes_from, :routes_to

  # The optional prose a Location profile records, in the order the editor and
  # the details page present it. `description` stays outside the list: it is the
  # record's summary and already has its own field everywhere.
  #
  # One list, read by the editor's field descriptors, the details page, the list
  # filter, the API, and the search body. A profile field added to the schema but
  # forgotten in one of those five places is the drift this constant prevents.
  PROFILE_FIELDS = %i[
    sensory_sight sensory_sound sensory_smell sensory_taste sensory_touch
    layout_structure layout_key_areas layout_pathways layout_entrances_exits layout_points_of_interest
    significance
    history_significant_events history_past_occupants history_changes
    access_controlled_by access_granted_how access_security access_restrictions
  ].freeze

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

  # Everything the search engine should find on this Location: the summary and
  # every profile answer, so a reader can find a place by what it smells like or
  # who controls it, not only by its name.
  def search_description
    [ description, *PROFILE_FIELDS.map { |field| public_send(field) } ].compact_blank.join(" ")
  end
end
