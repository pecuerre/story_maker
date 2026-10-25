class FactionTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable
  include HasDiscussion

  searchable kind: "tag", title: :name, body: :description, route: "faction_tag", taxonomy: "Faction"
  soft_deletes :children

  belongs_to :universe
  has_many_tagged :faction, scope: :universe_id

  validates :name, presence: true
end
