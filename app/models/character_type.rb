class CharacterType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes

  belongs_to :story
  has_many_typed :character

  validates :name, presence: true
end
