class Item < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  has_many_tags :item_tag
  has_many :ownerships, dependent: :destroy

  validates :name, presence: true
end
