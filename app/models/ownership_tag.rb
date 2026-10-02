class OwnershipTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable
  include HasDiscussion

  searchable kind: "tag", title: :name, body: :description, route: "ownership_tag", taxonomy: "Ownership"
  soft_deletes :children

  belongs_to :universe
  has_many_tagged :ownership, scope: :universe_id

  validates :name, presence: true
end
