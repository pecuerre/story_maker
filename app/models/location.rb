class Location < ApplicationRecord
  include Hierarchical
  include HasManyTags
  include HasSlug
  include InvalidatesMenuCounts

  invalidates_menu_counts_for :universe

  belongs_to :universe
  has_many_tags :location_tag, scope: :universe_id

  validates :name, presence: true
end
