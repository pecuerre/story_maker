class CharacterTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug
  include Searchable
  searchable kind: "tag", title: :name, body: :description, route: "character_tag", taxonomy: "Character"

  belongs_to :universe
  has_many_tagd :character, scope: :universe_id

  validates :name, presence: true
end
