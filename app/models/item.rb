class Item < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include InvalidatesMenuCounts
  include InvalidatesUniverseSummary
  include Searchable
  include HasDiscussion

  searchable kind: "item", title: :name, body: :search_description, route: "item"
  invalidates_menu_counts_for :universe
  soft_deletes :children, :ownerships, :scene_items

  belongs_to :universe
  has_many_tags :item_tag, scope: :universe_id
  has_many :ownerships, dependent: :destroy
  # The Scene presence side. Deleting an Item removes its presence links; it
  # never removes a Scene, and the Item itself is shared by every Story.
  # `:destroy` rather than `:delete_all`: a presence link carries a discussion,
  # and `delete_all` skips the callbacks that would take it along. See Character.
  has_many :scene_items, dependent: :destroy

  validates :name, presence: true

  # The short summary is one line of plain text and is never rendered as
  # Markdown, but it may carry the same `[[kind:slug]]` references the
  # description does: the details page links them and a list row names them
  # without a link. The description is Markdown and is rendered by
  # `MarkdownDescription` when a page shows it. Both are part of the record's
  # search body, so a reader can find an object by what its profile says.
  #
  # The description is the whole profile: its `##` sections carry what the
  # separate what-it-does, origin, constraints, and jargon columns used to hold,
  # so a reader can still find an object by what it does, where it came from, or
  # what it cannot do.
  def search_description
    [ summary, description ].compact_blank.join(" ")
  end
end
