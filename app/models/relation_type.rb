class RelationType < ApplicationRecord
  include Hierarchical
  include HasColor
  include HasManyTypes
  include HasSlug

  belongs_to :universe
  has_many_typed :relation

  validates :name, presence: true
  validates :inverse, presence: true, unless: :symmetric?
end