class ItemTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable

  searchable kind: "tag", title: :name, body: :description, route: "item_tag", taxonomy: "Item"
  soft_deletes :children

  belongs_to :universe
  has_many_tagged :item, scope: :universe_id

  validates :name, presence: true
end
