class ItemTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tagd :item, scope: :universe_id

  validates :name, presence: true
end
