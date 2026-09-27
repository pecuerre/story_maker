class OwnershipTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "ownership_tag", taxonomy: "Ownership"

  belongs_to :universe
  has_many_tagd :ownership, scope: :universe_id

  validates :name, presence: true
end
