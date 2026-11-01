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

  # The short summary is one line of plain text and is never rendered as
  # Markdown, but it may carry the same `[[kind:slug]]` references the
  # description does: the details page links them and a list row names them
  # without a link. The description is Markdown and is rendered by
  # `MarkdownDescription` when a page shows it. Both are part of the record's
  # search body, so a reader can find a place by what its profile says.
  #
  # The description is the whole profile: its `##` sections carry what the
  # separate sensory, layout, history, and access columns used to hold, so a
  # reader can still find a place by what it smells like or who controls it, not
  # only by its name.
  def search_description
    [ summary, description ].compact_blank.join(" ")
  end
end
