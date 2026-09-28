class Item < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include SoftDeletable
  include InvalidatesMenuCounts
  include Searchable
  searchable kind: "item", title: :name, body: :description, route: "item"

  invalidates_menu_counts_for :universe

  soft_deletes :children, :ownerships, :scene_items

  belongs_to :universe
  has_many_tags :item_tag, scope: :universe_id
  has_many :ownerships, dependent: :destroy
  # The Scene presence side. Deleting an Item removes its presence links; it
  # never removes a Scene, and the Item itself is shared by every Story.
  has_many :scene_items, dependent: :delete_all

  validates :name, presence: true
end
