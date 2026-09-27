class ItemTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "item_tag", taxonomy: "Item"

  belongs_to :universe
  has_many_tagd :item, scope: :universe_id

  validates :name, presence: true
end
