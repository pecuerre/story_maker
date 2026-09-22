class ItemTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tagd :item

  validates :name, presence: true
end
