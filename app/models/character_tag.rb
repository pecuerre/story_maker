class CharacterTag < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTags
  include HasSlug

  belongs_to :universe
  has_many_tagd :character, scope: :universe_id

  validates :name, presence: true
end
