class CharacterTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include HasPhoto
  include SoftDeletable
  include Searchable

  searchable kind: "tag", title: :name, body: :description, route: "character_tag", taxonomy: "Character"
  soft_deletes :children

  belongs_to :universe
  has_many_tagged :character, scope: :universe_id

  validates :name, presence: true
end
