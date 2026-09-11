class RelationType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes

  belongs_to :story
  has_many_typed :relation

  validates :name, presence: true
  validates :inverse, presence: true, unless: :symmetric?
end