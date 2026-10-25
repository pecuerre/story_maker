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

  # The optional prose an Item profile records, in the order the editor and the
  # details page present it. `description` stays outside the list: it is the
  # record's summary of what the item is, and it already has its own field
  # everywhere. Ownership is also absent: who holds an item is a dated Ownership
  # record, not an answer stored on the item, so it updates as ownership changes.
  #
  # One list, read by the editor's fields, the details page, the list filter, the
  # API, and the search body. A profile field added to the schema but forgotten
  # in one of those places is the drift this constant prevents.
  PROFILE_FIELDS = %i[
    what_it_does how_it_is_used side_effects origin value cannot constraints history jargon
  ].freeze

  belongs_to :universe
  has_many_tags :item_tag, scope: :universe_id
  has_many :ownerships, dependent: :destroy
  # The Scene presence side. Deleting an Item removes its presence links; it
  # never removes a Scene, and the Item itself is shared by every Story.
  # `:destroy` rather than `:delete_all`: a presence link carries a discussion,
  # and `delete_all` skips the callbacks that would take it along. See Character.
  has_many :scene_items, dependent: :destroy

  validates :name, presence: true

  # Everything the search engine should find on this Item: the summary and every
  # profile answer, so a reader can find an object by what it does, where it came
  # from, or what it cannot do, not only by its name.
  def search_description
    [ description, *PROFILE_FIELDS.map { |field| public_send(field) } ].compact_blank.join(" ")
  end
end
